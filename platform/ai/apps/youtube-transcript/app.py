from __future__ import annotations

import json
import logging
import os
import re
import urllib.error
import urllib.request

from fastapi import FastAPI, Query, Request
from fastapi.responses import JSONResponse
from fastmcp import FastMCP
from starlette.concurrency import run_in_threadpool

log = logging.getLogger("youtube-transcript")

LANGUAGES = [s.strip() for s in os.environ.get("YT_LANGUAGES", "en").split(",") if s.strip()]
METADATA_ENABLED = os.environ.get("YT_METADATA", "true").lower() not in {"0", "false", "no"}
# The knowledge chunker splits on headings; one heading per interval keeps
# chunks citeable to a point in the video.
HEADING_INTERVAL = max(30, int(os.environ.get("YT_HEADING_INTERVAL_SECONDS", "240")))
KB_INGEST_URL = os.environ.get("KB_INGEST_URL", "http://kb-ingest.ai.svc.cluster.local:3000").rstrip("/")
KB_INGEST_TOKEN = os.environ.get("KB_INGEST_TOKEN", "").strip()
KB_INGEST_PATH_PREFIX = os.environ.get("KB_INGEST_PATH_PREFIX", "tree/youtube/")
KB_INGEST_TIMEOUT = float(os.environ.get("KB_INGEST_TIMEOUT_SECONDS", "300"))

VIDEO_ID = Query(None, description="11-character YouTube video id")
VIDEO_URL = Query(None, description="YouTube URL (watch, youtu.be, shorts, embed); used when video_id is unset")

# Every route with an operation_id becomes an MCP tool of that name at /mcp.
api = FastAPI(title="youtube-transcript", version="0.2.1")

_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")
_URL_ID_RE = re.compile(
    r"(?:v=|/shorts/|/embed/|youtu\.be/)([A-Za-z0-9_-]{11})"
)


class TranscriptUnavailable(Exception):
    def __init__(self, reason: str, detail: str = "") -> None:
        super().__init__(detail or reason)
        self.reason = reason
        self.detail = detail


class TranscriptBlocked(Exception):
    """YouTube rate-limited or IP-blocked the caption endpoint.

    Never an `available: false` — that means "this video has no captions", and
    a caller who conflates the two records a transient block as a permanent
    content fact.
    """


def _blocked_body(video_id: str, exc: Exception) -> dict:
    return {"error": "blocked", "video_id": video_id, "detail": str(exc)}


def parse_video_id(value: str) -> str:
    candidate = (value or "").strip()
    if not candidate:
        raise ValueError("video_id or url is required")
    if _ID_RE.match(candidate):
        return candidate
    m = _URL_ID_RE.search(candidate)
    if m:
        return m.group(1)
    raise ValueError(f"could not parse a video id from {value!r}")


def _proxy_config():
    """Webshare or generic proxy — YouTube rate-limits datacenter IPs hard."""
    user = os.environ.get("WEBSHARE_PROXY_USERNAME")
    password = os.environ.get("WEBSHARE_PROXY_PASSWORD")
    if user and password:
        from youtube_transcript_api.proxies import WebshareProxyConfig

        return WebshareProxyConfig(proxy_username=user, proxy_password=password)
    http_url = os.environ.get("YT_HTTP_PROXY")
    https_url = os.environ.get("YT_HTTPS_PROXY")
    if http_url or https_url:
        from youtube_transcript_api.proxies import GenericProxyConfig

        return GenericProxyConfig(http_url=http_url, https_url=https_url)
    return None


def fetch_segments(video_id: str) -> list[dict]:
    from youtube_transcript_api import YouTubeTranscriptApi
    from youtube_transcript_api._errors import CouldNotRetrieveTranscript, RequestBlocked

    proxy = _proxy_config()
    try:
        # youtube-transcript-api >= 1.0 instance API.
        api = YouTubeTranscriptApi(proxy_config=proxy) if proxy else YouTubeTranscriptApi()
        raw = api.fetch(video_id, languages=LANGUAGES)
        snippets = getattr(raw, "snippets", raw)
        return [
            {
                "text": s.text if hasattr(s, "text") else s["text"],
                "start": float(s.start if hasattr(s, "start") else s["start"]),
                "duration": float(
                    s.duration if hasattr(s, "duration") else s.get("duration", 0.0)
                ),
            }
            for s in snippets
        ]
    except TypeError:
        # Legacy (<1.0) static API; no proxy_config kwarg.
        raw = YouTubeTranscriptApi.get_transcript(video_id, languages=LANGUAGES)
        return [
            {
                "text": s["text"],
                "start": float(s["start"]),
                "duration": float(s.get("duration", 0.0)),
            }
            for s in raw
        ]
    except RequestBlocked as exc:
        raise TranscriptBlocked(str(exc)) from exc
    except CouldNotRetrieveTranscript as exc:
        raise TranscriptUnavailable("no_transcript", str(exc)) from exc


def fetch_metadata(video_id: str) -> dict:
    if not METADATA_ENABLED:
        return {}
    try:
        import yt_dlp

        opts = {"quiet": True, "skip_download": True, "no_warnings": True}
        if proxy := (os.environ.get("YT_HTTPS_PROXY") or os.environ.get("YT_HTTP_PROXY")):
            opts["proxy"] = proxy
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(
                f"https://www.youtube.com/watch?v={video_id}", download=False
            )
    except Exception as exc:  # metadata is best-effort; captions still usable
        log.warning("metadata lookup failed for %s: %s", video_id, exc)
        return {}
    return {
        "title": info.get("title"),
        "uploader": info.get("uploader") or info.get("channel"),
        "channel_id": info.get("channel_id"),
        "upload_date": info.get("upload_date"),
        "duration": info.get("duration"),
    }


def _timestamp(seconds: float) -> str:
    total = int(seconds)
    return f"{total // 3600}:{total % 3600 // 60:02d}:{total % 60:02d}"


def _iso_date(upload_date: str | None) -> str | None:
    if upload_date and re.fullmatch(r"\d{8}", upload_date):
        return f"{upload_date[:4]}-{upload_date[4:6]}-{upload_date[6:]}"
    return None


def render_markdown(video_id: str, segments: list[dict], meta: dict) -> str:
    """Every caption segment, verbatim, under a `## h:mm:ss` heading per interval.

    Deterministic for a given transcript so a re-ingest is `unchanged`, not a
    re-embed; frontmatter is outside the knowledge doc_hash.
    """
    url = f"https://www.youtube.com/watch?v={video_id}"
    front = {
        "title": meta.get("title") or video_id,
        "tags": ["youtube"],
        "source_type": "youtube",
        "source_url": url,
        "video_id": video_id,
        "channel": meta.get("uploader"),
        "published_at": _iso_date(meta.get("upload_date")),
        "duration_seconds": meta.get("duration"),
        "captions_source": "unknown",
    }
    lines = ["---"]
    lines += [f"{k}: {json.dumps(v)}" for k, v in front.items() if v is not None]
    lines += ["---", ""]

    section_start: int | None = None
    buffer: list[str] = []

    def flush() -> None:
        if section_start is None or not buffer:
            return
        lines.append(f"## {_timestamp(section_start)}")
        lines.append(f"[{_timestamp(section_start)}]({url}&t={section_start}s)")
        lines.append("")
        lines.append(" ".join(buffer))
        lines.append("")

    for seg in segments:
        text = " ".join(str(seg.get("text") or "").split())
        if not text:
            continue
        bucket = int(seg.get("start") or 0) // HEADING_INTERVAL * HEADING_INTERVAL
        if bucket != section_start:
            flush()
            section_start, buffer = bucket, []
        buffer.append(text)
    flush()
    return "\n".join(lines).rstrip() + "\n"


def note_path(video_id: str) -> str:
    return f"{KB_INGEST_PATH_PREFIX.rstrip('/')}/{video_id}.md"


def post_to_kb_ingest(path: str, markdown: str, source_url: str, force: bool) -> dict:
    body = json.dumps(
        {
            "path": path,
            "markdown": markdown,
            "source_type": "youtube",
            "source_url": source_url,
            "force": force,
        }
    ).encode()
    headers = {"content-type": "application/json"}
    if KB_INGEST_TOKEN:
        headers["authorization"] = f"Bearer {KB_INGEST_TOKEN}"
    req = urllib.request.Request(
        f"{KB_INGEST_URL}/ingest", data=body, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=KB_INGEST_TIMEOUT) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:500]
        raise RuntimeError(f"kb-ingest returned {exc.code}: {detail}") from exc


async def _video_id_from(request: Request) -> str:
    raw = request.query_params.get("video_id") or request.query_params.get("url") or ""
    if not raw and request.method == "POST":
        try:
            body = await request.json()
        except ValueError:
            body = {}
        if isinstance(body, dict):
            raw = str(body.get("video_id") or body.get("url") or "")
    return parse_video_id(raw)


async def _note(video_id: str) -> tuple[str | None, dict]:
    """(markdown, info); markdown is None when the video has no captions."""
    try:
        segments = await run_in_threadpool(fetch_segments, video_id)
    except TranscriptUnavailable as exc:
        return None, {"reason": exc.reason, "detail": exc.detail}
    if not segments:
        return None, {"reason": "no_transcript", "detail": "transcript fetch returned no segments"}
    meta = await run_in_threadpool(fetch_metadata, video_id)
    return render_markdown(video_id, segments, meta), {"segments": len(segments), **meta}


@api.get("/markdown", operation_id="get_transcript_markdown")
async def markdown(
    request: Request, video_id: str | None = VIDEO_ID, url: str | None = VIDEO_URL
) -> JSONResponse:
    """Full transcript as a knowledge-tree markdown note (not stored).

    Every caption segment verbatim under `## h:mm:ss` headings, with frontmatter.
    `available: false` means the video has no captions.
    """
    try:
        video_id = await _video_id_from(request)
    except ValueError as exc:
        return JSONResponse({"error": "bad_request", "detail": str(exc)}, status_code=400)
    try:
        note, info = await _note(video_id)
    except TranscriptBlocked as exc:
        log.warning("caption endpoint blocked for %s: %s", video_id, exc)
        return JSONResponse(_blocked_body(video_id, exc), status_code=502)
    except Exception as exc:
        log.exception("markdown render failed for %s", video_id)
        return JSONResponse(
            {"error": "upstream_error", "video_id": video_id, "detail": str(exc)},
            status_code=502,
        )
    if note is None:
        return JSONResponse({"video_id": video_id, "available": False, **info})
    return JSONResponse(
        {"video_id": video_id, "available": True, "path": note_path(video_id),
         "markdown": note, **info}
    )


@api.post("/ingest", operation_id="ingest_video")
async def ingest(
    request: Request,
    video_id: str | None = VIDEO_ID,
    url: str | None = VIDEO_URL,
    force: bool = Query(False, description="re-embed even if the stored transcript is unchanged"),
) -> JSONResponse:
    """Store a video's full transcript in the knowledge base (Qdrant via kb-ingest).

    Writes tree/youtube/<video_id>.md. Re-ingesting an unchanged video returns
    `status: unchanged`. `available: false` means no captions; nothing is stored.
    """
    try:
        video_id = await _video_id_from(request)
    except ValueError as exc:
        return JSONResponse({"error": "bad_request", "detail": str(exc)}, status_code=400)
    try:
        note, info = await _note(video_id)
    except TranscriptBlocked as exc:
        log.warning("caption endpoint blocked for %s: %s", video_id, exc)
        return JSONResponse(_blocked_body(video_id, exc), status_code=502)
    except Exception as exc:
        log.exception("transcript fetch failed for %s", video_id)
        return JSONResponse(
            {"error": "upstream_error", "video_id": video_id, "detail": str(exc)},
            status_code=502,
        )
    if note is None:
        return JSONResponse({"video_id": video_id, "available": False, **info})

    path = note_path(video_id)
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        result = await run_in_threadpool(post_to_kb_ingest, path, note, url, force)
    except Exception as exc:
        log.exception("kb-ingest failed for %s", video_id)
        return JSONResponse(
            {"error": "ingest_error", "video_id": video_id, "path": path, "detail": str(exc)},
            status_code=502,
        )
    return JSONResponse(
        {"video_id": video_id, "available": True, "segments": info["segments"], **result}
    )


@api.get("/healthz", include_in_schema=False)
async def healthz() -> JSONResponse:
    return JSONResponse(
        {"status": "ok", "service": "youtube-transcript", "languages": LANGUAGES}
    )


@api.get("/transcript", operation_id="get_timed_transcript")
async def transcript(
    video_id: str | None = VIDEO_ID, url: str | None = VIDEO_URL
) -> JSONResponse:
    """Every caption segment of a video as `{text, start, duration}`, plus metadata.

    `available: false` means the video has no captions — do not invent one.
    """
    raw = video_id or url or ""
    try:
        video_id = parse_video_id(raw)
    except ValueError as exc:
        return JSONResponse({"error": "bad_request", "detail": str(exc)}, status_code=400)

    try:
        segments = await run_in_threadpool(fetch_segments, video_id)
    except TranscriptUnavailable as exc:
        # 200 + available=false, NOT 404: the framework already uses 404 for an
        # unmatched route, so overloading it makes a wrong URL indistinguishable
        # from a caption-less video.
        return JSONResponse(
            {
                "video_id": video_id,
                "available": False,
                "reason": exc.reason,
                "detail": exc.detail,
                "segments": [],
            }
        )
    except TranscriptBlocked as exc:
        log.warning("caption endpoint blocked for %s: %s", video_id, exc)
        return JSONResponse(_blocked_body(video_id, exc), status_code=502)
    except Exception as exc:
        log.exception("transcript fetch failed for %s", video_id)
        return JSONResponse(
            {"error": "upstream_error", "video_id": video_id, "detail": str(exc)},
            status_code=502,
        )

    if not segments:
        return JSONResponse(
            {
                "video_id": video_id,
                "available": False,
                "reason": "no_transcript",
                "detail": "transcript fetch returned no segments",
                "segments": [],
            }
        )

    meta = await run_in_threadpool(fetch_metadata, video_id)
    return JSONResponse(
        {
            "video_id": video_id,
            "available": True,
            "url": f"https://www.youtube.com/watch?v={video_id}",
            "segments": segments,
            "captions_source": "unknown",
            **meta,
        }
    )


@api.get("/video_info", operation_id="get_video_info")
async def video_info(
    video_id: str | None = VIDEO_ID, url: str | None = VIDEO_URL
) -> JSONResponse:
    """Title, uploader, channel_id, upload_date and duration for a video."""
    raw = video_id or url or ""
    try:
        video_id = parse_video_id(raw)
    except ValueError as exc:
        return JSONResponse({"error": "bad_request", "detail": str(exc)}, status_code=400)
    meta = await run_in_threadpool(fetch_metadata, video_id)
    if not meta:
        return JSONResponse(
            {"error": "no_metadata", "video_id": video_id}, status_code=404
        )
    return JSONResponse({"video_id": video_id, **meta})


mcp = FastMCP.from_fastapi(
    api,
    name="youtube-transcript",
    httpx_client_kwargs={"timeout": KB_INGEST_TIMEOUT + 60},
)
mcp_app = mcp.http_app(path="/mcp")

app = FastAPI(
    title=api.title,
    version=api.version,
    routes=[*mcp_app.routes, *api.routes],
    lifespan=mcp_app.lifespan,
)
