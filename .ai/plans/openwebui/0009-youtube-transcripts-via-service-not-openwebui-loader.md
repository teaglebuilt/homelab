# ADR-0009: YouTube transcripts enter through the youtube-transcript service, not OpenWebUI's loader

## Status
Proposed — the decision below is settled; procuring a caption proxy is not.

## Context
`youtube-transcript` 0.2.1 runs on mlops (`ai` namespace) as a ClusterMesh
global Service, exposing `GET /markdown`, `GET /transcript`, `GET /video_info`
and `POST /ingest`, mirrored as MCP tools. `POST /ingest` renders a note in code
(no LLM in the write path), writes `tree/youtube/<video_id>.md`, and POSTs it to
`kb-ingest`, which upserts into the Qdrant collection `knowledge`. Transcripts
carry a `## h:mm:ss` heading every `YT_HEADING_INTERVAL_SECONDS` with a `&t=<s>`
deep link, shaped so the knowledge repo's generic heading chunker handles them.

Open WebUI 0.13.0 also has a YouTube loader. It uses **the same library** —
`youtube_transcript_api`, with `GenericProxyConfig` from
`rag.youtube_loader_proxy_url` — so it shares the failure mode rather than
avoiding it.

Measured from the cluster on 2026-11-05:

* `youtube-transcript /transcript` → `502 {"error":"blocked"}`, detail *"YouTube
  is blocking requests from your IP"*.
* `yt-dlp` in-pod lists caption tracks successfully, then fails the caption
  download with **`429 Too Many Requests`**. The image also has no JS runtime
  and no impersonation target.
* `GET /video_info` (yt-dlp metadata) works. Metadata is not blocked; captions
  are.
* The `youtube-transcript-proxy` Secret, mounted `optional: true`, **does not
  exist** — no proxy is configured on either side.
* `kb_search(source_type="youtube")` returns nothing and `tree/youtube/` does
  not exist, so this pipeline has never once succeeded.

Two structural facts constrain the options:

* `is_youtube_url()` is tested **before** any loader selection, so neither the
  external *web* loader nor the external *document* loader can intercept a
  YouTube URL. `rag.youtube_loader_proxy_url` is the only lever OpenWebUI
  offers. (A regex/allowlist gap does route `m.youtube.com`,
  `youtube-nocookie.com` and `vid.plus` to the web loader — that is a bug, not
  an interface, and must not be built on.)
* `validate_url()` blocks private IPs, so a chat-pasted URL cannot be pointed at
  the in-cluster service.

## Decision Drivers
* **Must not** create a second index of the same content
* **Must** keep the knowledge repo the sole owner of indexing (ADR-0005)
* **Must** keep transcripts reachable by agents, not only by chat
* **Should** preserve timestamps and deep links
* **Should not** take on a paid dependency before it is needed

## Considered Options
### Option 1: OpenWebUI's native YouTube loader
- **Pros**: zero new code; paste a URL in chat
- **Cons**: writes to a collection keyed `sha256(url)[:63]`, i.e. a second index
  invisible to agents and to `kb_search`; no File row, so no stable citation;
  blocked by the same IP reputation anyway; its proxy knob is generic-URL only,
  so it cannot use a rotating Webshare pool
### Option 2: The youtube-transcript service, with a caption proxy
- **Pros**: one index, one owner; agents and chat both see it through ADR-0005's
  two front doors; keeps timestamp headings and deep links; already supports
  `WEBSHARE_PROXY_USERNAME`/`_PASSWORD` (rotating residential, the library's
  first-class fix) or `YT_HTTP_PROXY`/`YT_HTTPS_PROXY`, and applies the proxy to
  yt-dlp as well as the captions API
- **Cons**: a paid external dependency and a new egress path
### Option 3: Laptop-side ingest via the `ingest-youtube` skill → `POST /ingest`
- **Pros**: free; works today; no datacenter IP involved
- **Cons**: manual; no unattended ingestion
### Option 4: Harden the image — `curl_cffi` impersonation plus a deno JS runtime
- **Pros**: cheap to test; no recurring cost
- **Cons**: does not address ASN-level blocking, which is what the 429 and the
  library's `IpBlocked` class indicate; `PoTokenRequired` is unaffected

## Decision
**Option 2** is the only in-cluster ingestion path; **Option 3** is the
zero-cost path available today. OpenWebUI's native YouTube loader stays unused —
`rag.youtube_loader_proxy_url` remains empty, which keeps the second index from
ever being created.

Whether to buy a proxy now (Option 2) or ingest from the laptop until volume
justifies one (Option 3) is deferred; both write to the same place, so the
choice is reversible and changes nothing downstream.

## Rationale
The integration question and the access question are independent, and only the
access question is hard. Once captions are obtainable, `POST /ingest` already
lands them in `knowledge`, where ADR-0005's two front doors pick them up for
free. Choosing OpenWebUI's loader would solve the easy half and reintroduce the
drift ADR-0005 exists to prevent.

## Consequences
### Positive
- YouTube content appears in chat and to agents through one index
- Timestamp deep links survive into citations
- No OpenWebUI-side configuration, so nothing to keep in sync
### Negative
- Unattended ingestion stays blocked until a proxy exists
- A proxy is a recurring cost and an egress path for a service that fetches
  URLs chosen elsewhere; it deserves its own egress policy
- `PoTokenRequired` remains a possible hard stop that no proxy fixes
- Metadata loss: `video_id`, `channel`, `published_at` and `duration_seconds`
  are written to the note's frontmatter but stripped before Qdrant, so they are
  neither filterable nor citeable. Only `title`, `tags`, `source_type` and
  `source_url` survive, and only because the service passes them as explicit
  POST fields.

## Implementation Notes
- Create the `youtube-transcript-proxy` Secret with either
  `WEBSHARE_PROXY_USERNAME` + `WEBSHARE_PROXY_PASSWORD` (preferred — the
  library's `WebshareProxyConfig` rotates) or `YT_HTTP_PROXY` + `YT_HTTPS_PROXY`.
  The Deployment already mounts it `envFrom … optional: true`; no manifest
  change is needed.
- Verify with `GET /transcript?video_id=…` returning `available: true` before
  ingesting in bulk. `GET /video_info` is not a proxy test — it was never
  blocked.
- Narrow `KB_INGEST_PATH_PREFIXES` to `tree/youtube/` before routine use. At the
  shipped default `tree/`, an ingest for a tree-owned path re-embeds and then
  `delete_path`s the tree's own points, because `kb sync` writes no `doc_hash`
  while `kb-ingest` dedups on it.
- `kb-ingest`'s `/exists` is not behind `_authorized`, and `KB_INGEST_TOKEN` is
  optional on both ends — unset means the write plane is open to anything that
  can reach the Service.
- Do not set `WEB_LOADER_ENGINE=external` to capture YouTube via the
  `m.youtube.com` regex gap.
- If ASR is ever wanted for caption-less videos, it belongs in this service, not
  in OpenWebUI — the write path must stay single-owner.

## Related Decisions
- ADR-0005, ADR-0007
