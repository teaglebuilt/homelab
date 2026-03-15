#!/usr/bin/env python3
"""
Generate a combined RSS/Atom feed from YouTube channel subscriptions.

Reads youtube-subscriptions.yaml, fetches each channel's Atom feed,
merges entries, and writes a combined feed XML file.

Usage:
    python3 generate_rss.py [--input FILE] [--output FILE] [--limit N]
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

try:
    import yaml
except ImportError:
    print("PyYAML not found. Installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml", "--quiet", "--break-system-packages"])
    import yaml


YOUTUBE_FEED_URL = "https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
USER_AGENT = "Mozilla/5.0 (compatible; YouTubeFeedAggregator/1.0)"

ATOM_NS = "http://www.w3.org/2005/Atom"
MEDIA_NS = "http://search.yahoo.com/mrss/"
YT_NS = "http://www.youtube.com/xml/schemas/2015"


def load_subscriptions(path: str) -> dict:
    with open(path, "r") as f:
        return yaml.safe_load(f)


def fetch_channel_feed(channel_id: str, channel_name: str) -> list[dict]:
    """Fetch and parse a single YouTube channel's Atom feed."""
    url = YOUTUBE_FEED_URL.format(channel_id=channel_id)
    entries = []

    try:
        req = Request(url, headers={"User-Agent": USER_AGENT})
        with urlopen(req, timeout=15) as resp:
            tree = ET.parse(resp)
            root = tree.getroot()

            for entry in root.findall(f"{{{ATOM_NS}}}entry"):
                video_id = entry.findtext(f"{{{YT_NS}}}videoId", "")
                title = entry.findtext(f"{{{ATOM_NS}}}title", "")
                published = entry.findtext(f"{{{ATOM_NS}}}published", "")
                updated = entry.findtext(f"{{{ATOM_NS}}}updated", "")

                link_el = entry.find(f"{{{ATOM_NS}}}link")
                link = link_el.get("href", "") if link_el is not None else ""

                # Media thumbnail
                media_group = entry.find(f"{{{MEDIA_NS}}}group")
                thumbnail = ""
                description = ""
                if media_group is not None:
                    thumb_el = media_group.find(f"{{{MEDIA_NS}}}thumbnail")
                    if thumb_el is not None:
                        thumbnail = thumb_el.get("url", "")
                    desc_el = media_group.find(f"{{{MEDIA_NS}}}description")
                    if desc_el is not None and desc_el.text:
                        description = desc_el.text[:500]  # Truncate long descriptions

                entries.append({
                    "video_id": video_id,
                    "title": title,
                    "link": link,
                    "published": published,
                    "updated": updated,
                    "channel_name": channel_name,
                    "channel_id": channel_id,
                    "thumbnail": thumbnail,
                    "description": description,
                })

    except (URLError, HTTPError, ET.ParseError) as e:
        print(f"  ⚠ Failed to fetch feed for {channel_name} ({channel_id}): {e}", file=sys.stderr)

    return entries


def generate_rss_xml(entries: list[dict], metadata: dict) -> str:
    """Generate an RSS 2.0 XML string from merged entries."""
    now = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    title = metadata.get("title", "YouTube Subscriptions Feed")
    description = metadata.get("description", "Aggregated YouTube feed")
    site_url = metadata.get("site_url", "https://www.youtube.com")

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">',
        '  <channel>',
        f'    <title>{_escape(title)}</title>',
        f'    <description>{_escape(description)}</description>',
        f'    <link>{_escape(site_url)}</link>',
        f'    <lastBuildDate>{now}</lastBuildDate>',
        f'    <generator>youtube-skill generate_rss.py</generator>',
    ]

    for entry in entries:
        pub_date = _format_rss_date(entry["published"])
        lines.append('    <item>')
        lines.append(f'      <title>{_escape(entry["title"])}</title>')
        lines.append(f'      <link>{_escape(entry["link"])}</link>')
        lines.append(f'      <guid isPermaLink="true">{_escape(entry["link"])}</guid>')
        if pub_date:
            lines.append(f'      <pubDate>{pub_date}</pubDate>')
        lines.append(f'      <author>{_escape(entry["channel_name"])}</author>')
        if entry.get("description"):
            desc = entry["description"]
            if entry.get("thumbnail"):
                desc = f'<img src="{entry["thumbnail"]}" /><br/>{desc}'
            lines.append(f'      <description><![CDATA[{desc}]]></description>')
        if entry.get("thumbnail"):
            lines.append(f'      <media:thumbnail url="{_escape(entry["thumbnail"])}" />')
        lines.append('    </item>')

    lines.append('  </channel>')
    lines.append('</rss>')

    return "\n".join(lines)


def _escape(text: str) -> str:
    """Escape XML special characters."""
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )


def _format_rss_date(iso_date: str) -> str:
    """Convert ISO 8601 date to RFC 822 for RSS."""
    try:
        dt = datetime.fromisoformat(iso_date.replace("Z", "+00:00"))
        return dt.strftime("%a, %d %b %Y %H:%M:%S +0000")
    except (ValueError, AttributeError):
        return ""


def update_yaml_timestamp(path: str):
    """Update the last_updated field in the YAML file."""
    with open(path, "r") as f:
        data = yaml.safe_load(f)

    if "feed_metadata" in data:
        data["feed_metadata"]["last_updated"] = datetime.now(timezone.utc).isoformat()

    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)


def main():
    parser = argparse.ArgumentParser(description="Generate combined RSS feed from YouTube subscriptions")
    parser.add_argument("--input", "-i", default="youtube-subscriptions.yaml", help="Path to subscriptions YAML")
    parser.add_argument("--output", "-o", default="youtube-feed.xml", help="Output RSS feed path")
    parser.add_argument("--limit", "-l", type=int, default=50, help="Max items in feed (default: 50)")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: {input_path} not found", file=sys.stderr)
        sys.exit(1)

    data = load_subscriptions(str(input_path))
    channels = data.get("channels", [])
    metadata = data.get("feed_metadata", {})

    if not channels:
        print("No channels found in subscriptions file.")
        sys.exit(0)

    print(f"Fetching feeds for {len(channels)} channels...")
    all_entries = []

    for ch in channels:
        name = ch.get("name", "Unknown")
        cid = ch.get("channel_id", "")
        if not cid:
            print(f"  ⚠ Skipping {name}: no channel_id", file=sys.stderr)
            continue

        print(f"  → {name} ({cid})")
        entries = fetch_channel_feed(cid, name)
        all_entries.extend(entries)
        print(f"    Found {len(entries)} videos")

    # Sort by published date, newest first
    all_entries.sort(key=lambda e: e.get("published", ""), reverse=True)

    # Limit
    if args.limit and args.limit > 0:
        all_entries = all_entries[: args.limit]

    # Generate RSS
    rss_xml = generate_rss_xml(all_entries, metadata)

    output_path = Path(args.output)
    output_path.write_text(rss_xml, encoding="utf-8")
    print(f"\n✅ Generated {output_path} with {len(all_entries)} items")

    # Update timestamp in YAML
    update_yaml_timestamp(str(input_path))
    print(f"✅ Updated last_updated in {input_path}")


if __name__ == "__main__":
    main()
