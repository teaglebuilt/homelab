#!/usr/bin/env python3
"""Talk to the self-hosted model through the ai-gateway.

    infer.py                              interactive chat
    infer.py "why is the sky blue?"       one-shot
    git diff | infer.py "review this"     piped stdin becomes context
    infer.py -s "You are terse." "hi"     custom system prompt

Requests go to the `vllm-selfhosted` AgentgatewayBackend via svc/ai-gateway in the
`ai` namespace. The connection is tunnelled with `kubectl port-forward` so it works
from any network; set AI_GATEWAY_URL (or --url) to hit the LoadBalancer directly
when you are on the 192.168.2.0/24 VLAN.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
KUBECONFIG = REPO_ROOT / "kubernetes" / "generated" / "mlops" / "kubeconfig"
NAMESPACE = "ai"
SERVICE = "ai-gateway"
SERVICE_PORT = 80
ROUTE_PREFIX = "/vllm"
DEFAULT_MODEL = "vllm-selfhosted"
LAN_URL = "http://192.168.2.202"

BANNER = "\033[2m"
RESET = "\033[0m"


class GatewayError(RuntimeError):
    pass


def _free_port() -> int:
    with contextlib.closing(socket.socket()) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@contextlib.contextmanager
def gateway(url_override: str | None):
    """Yield the base URL of the ai-gateway, port-forwarding for the duration if needed."""
    if url_override:
        yield url_override.rstrip("/")
        return

    if not KUBECONFIG.exists():
        raise GatewayError(
            f"no kubeconfig at {KUBECONFIG}; set AI_GATEWAY_URL={LAN_URL} to use the LoadBalancer"
        )

    local_port = _free_port()
    proc = subprocess.Popen(
        ["kubectl", "port-forward", "-n", NAMESPACE,
         f"svc/{SERVICE}", f"{local_port}:{SERVICE_PORT}"],
        env={**os.environ, "KUBECONFIG": str(KUBECONFIG)},
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    try:
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                raise GatewayError(f"port-forward failed: {proc.stdout.read().strip()}")
            with contextlib.closing(socket.socket()) as s:
                s.settimeout(0.5)
                if s.connect_ex(("127.0.0.1", local_port)) == 0:
                    break
            time.sleep(0.25)
        else:
            raise GatewayError("port-forward never became ready")
        yield f"http://127.0.0.1:{local_port}"
    finally:
        proc.terminate()
        with contextlib.suppress(subprocess.TimeoutExpired):
            proc.wait(timeout=5)


def complete(base: str, messages: list[dict], opts: argparse.Namespace):
    """Stream assistant content deltas for one turn, yielding text as it arrives."""
    payload = {
        "model": opts.model,
        "messages": messages,
        "max_tokens": opts.max_tokens,
        "temperature": opts.temperature,
        "stream": True,
    }
    req = urllib.request.Request(
        f"{base}{ROUTE_PREFIX}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=opts.timeout) as resp:
            for raw in resp:
                line = raw.decode().strip()
                if not line.startswith("data: "):
                    continue
                body = line[6:]
                if body == "[DONE]":
                    return
                choices = json.loads(body).get("choices") or []
                if not choices:
                    continue  # usage-only and keepalive chunks carry no choices
                delta = (choices[0].get("delta") or {}).get("content")
                if delta:
                    yield delta
    except urllib.error.HTTPError as exc:
        raise GatewayError(f"HTTP {exc.code}: {exc.read().decode()[:400]}") from exc
    except urllib.error.URLError as exc:
        raise GatewayError(f"cannot reach the gateway: {exc.reason}") from exc


def say(base: str, messages: list[dict], opts: argparse.Namespace) -> str:
    """Run one turn, printing as it streams, and return the full reply."""
    chunks = []
    for delta in complete(base, messages, opts):
        chunks.append(delta)
        print(delta, end="", flush=True)
    print()
    return "".join(chunks)


def one_shot(base: str, prompt: str, opts: argparse.Namespace) -> int:
    messages = ([{"role": "system", "content": opts.system}] if opts.system else [])
    messages.append({"role": "user", "content": prompt})
    say(base, messages, opts)
    return 0


def repl(base: str, opts: argparse.Namespace) -> int:
    messages = ([{"role": "system", "content": opts.system}] if opts.system else [])
    print(f"{BANNER}{opts.model} via ai-gateway - /reset clears history, "
          f"/system <text> sets the system prompt, Ctrl-D exits{RESET}")

    while True:
        try:
            line = input("\n\033[1m>\033[0m ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0

        if not line:
            continue
        if line in ("/exit", "/quit"):
            return 0
        if line == "/reset":
            messages = ([{"role": "system", "content": opts.system}] if opts.system else [])
            print(f"{BANNER}history cleared{RESET}")
            continue
        if line.startswith("/system"):
            opts.system = line[len("/system"):].strip()
            messages = [m for m in messages if m["role"] != "system"]
            if opts.system:
                messages.insert(0, {"role": "system", "content": opts.system})
            print(f"{BANNER}system prompt {'set' if opts.system else 'cleared'}{RESET}")
            continue

        messages.append({"role": "user", "content": line})
        print()
        try:
            messages.append({"role": "assistant", "content": say(base, messages, opts)})
        except GatewayError as exc:
            messages.pop()
            print(f"error: {exc}", file=sys.stderr)

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("prompt", nargs="*", help="prompt; omit for an interactive session")
    parser.add_argument("-s", "--system", default=os.environ.get("AI_SYSTEM_PROMPT"),
                        help="system prompt")
    parser.add_argument("-m", "--model", default=os.environ.get("AI_MODEL", DEFAULT_MODEL))
    parser.add_argument("-t", "--temperature", type=float, default=0.7)
    parser.add_argument("-n", "--max-tokens", type=int, default=1024)
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--url", default=os.environ.get("AI_GATEWAY_URL"),
                        help=f"gateway base URL, skipping port-forward (LAN: {LAN_URL})")
    opts = parser.parse_args()

    prompt = " ".join(opts.prompt)
    if not sys.stdin.isatty():
        piped = sys.stdin.read().strip()
        if piped:
            prompt = f"{prompt}\n\n{piped}".strip() if prompt else piped

    try:
        with gateway(opts.url) as base:
            return one_shot(base, prompt, opts) if prompt else repl(base, opts)
    except GatewayError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
