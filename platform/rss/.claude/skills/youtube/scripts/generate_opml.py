#!/usr/bin/env python3
"""
Generate an OPML file from YouTube channel subscriptions.

OPML can be imported into any RSS reader (Feedly, Inoreader, NetNewsWire, etc.)

Usage:
    python3 generate_opml.py [--input FILE] [--output FILE]
"""

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path
from xml.sax.saxutils import escape

try:
    import yaml
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml", "--quiet", "--break-system-packages"])
    import yaml


YOUTUBE_FEED_URL = "https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"


def load_subscriptions(path: str) -> dict:
    with open(path, "r") as f:
        return yaml.safe_load(f)


def generate_opml(data: dict) -> str:
    channels = data.get("channels", [])
    metadata = data.get("feed_metadata", {})
    title = metadata.get("title", "YouTube Subscriptions")
    now = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")

    # Group channels by first tag (or "Uncategorized")
    groups: dict[str, list] = {}
    for ch in channels:
        tags = ch.get("tags", [])
        group = tags[0] if tags else "uncategorized"
        groups.setdefault(group, []).append(ch)

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<opml version="2.0">',
        '  <head>',
        f'    <title>{escape(title)}</title>',
        f'    <dateCreated>{now}</dateCreated>',
        '  </head>',
        '  <body>',
    ]

    for group_name, group_channels in sorted(groups.items()):
        lines.append(f'    <outline text="{escape(group_name)}" title="{escape(group_name)}">')
        for ch in sorted(group_channels, key=lambda c: c.get("name", "")):
            name = escape(ch.get("name", "Unknown"))
            cid = ch.get("channel_id", "")
            feed_url = YOUTUBE_FEED_URL.format(channel_id=cid)
            html_url = f"https://www.youtube.com/channel/{cid}"
            lines.append(
                f'      <outline type="rss" text="{name}" title="{name}" '
                f'xmlUrl="{escape(feed_url)}" htmlUrl="{escape(html_url)}" />'
            )
        lines.append('    </outline>')

    lines.append('  </body>')
    lines.append('</opml>')

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate OPML from YouTube subscriptions")
    parser.add_argument("--input", "-i", default="youtube-subscriptions.yaml", help="Subscriptions YAML path")
    parser.add_argument("--output", "-o", default="youtube-subscriptions.opml", help="Output OPML path")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: {input_path} not found", file=sys.stderr)
        sys.exit(1)

    data = load_subscriptions(str(input_path))
    opml = generate_opml(data)

    output_path = Path(args.output)
    output_path.write_text(opml, encoding="utf-8")

    channel_count = len(data.get("channels", []))
    print(f"✅ Generated {output_path} with {channel_count} channels")


if __name__ == "__main__":
    main()
