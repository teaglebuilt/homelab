---
name: youtube
description: Manage YouTube channel subscriptions stored in a YAML file and generate RSS feeds. Use when the user wants to add, remove, list, or search YouTube subscriptions, generate an RSS/Atom feed or OPML file from their subscriptions, or look up YouTube channel IDs. Triggers on mentions of "youtube", "subscriptions", "channels", "rss feed", or "opml".
---

# YouTube Subscription & RSS Feed Manager

Manage YouTube channel subscriptions in a YAML data file and generate RSS feeds from them.

## Data File

Subscriptions are stored in `youtube-subscriptions.yaml` at the project root (or a path the user specifies). If it doesn't exist yet, create it with the initial structure shown in `references/schema.md`.

## Commands

### Add a channel

1. User provides a channel name, URL, handle (@handle), or channel ID
2. If only a name or handle is given, use web search or the YouTube page to resolve the **channel_id** (the `UC...` string)
3. Append an entry to the `channels` list in the YAML file
4. Confirm what was added

Entry fields:
```yaml
- name: "Channel Name"
  channel_id: "UCxxxxxxxxxx"
  handle: "@handle"          # optional
  tags: [tech, ai]           # optional, user-defined categories
  added: "2026-02-17"        # date added
  notes: ""                  # optional user notes
```

### Remove a channel

Find by name (fuzzy match) or channel_id, remove from YAML, confirm.

### List / search channels

Display channels, optionally filtered by tag. Show name, handle, tags, and the RSS feed URL:
`https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}`

### Generate RSS feed

Run `scripts/generate_rss.py` to produce a combined RSS/Atom XML feed file from all subscriptions. The script:
- Reads `youtube-subscriptions.yaml`
- Fetches each channel's YouTube Atom feed
- Merges entries into a single feed sorted by publish date (newest first)
- Writes to `youtube-feed.xml` (or user-specified output path)
- Optionally limits to N most recent items (default: 50)

Usage:
```bash
python3 scripts/generate_rss.py [--input youtube-subscriptions.yaml] [--output youtube-feed.xml] [--limit 50]
```

### Generate OPML

Run `scripts/generate_opml.py` to produce an OPML file importable into any RSS reader (Feedly, Inoreader, NetNewsWire, etc.):

```bash
python3 scripts/generate_opml.py [--input youtube-subscriptions.yaml] [--output youtube-subscriptions.opml]
```

### Refresh feed

Re-run the RSS generation script to pull latest videos. This is what the user means by "update my rss feed".

## YouTube Channel ID Resolution

To find a channel_id from a URL or handle:
- Channel page URL: `https://www.youtube.com/channel/UCxxxxxxxxxx` → extract directly
- Handle URL: `https://www.youtube.com/@handle` → fetch page source, find `channel_id` in meta tags or canonical URL
- Search: use web search for `"youtube" "channel_id" "@handle"` or `site:youtube.com @handle`

## Important Notes

- The YAML file is the source of truth — always read it before modifying
- Preserve existing entries and formatting when adding/removing
- YouTube Atom feeds are publicly available, no API key needed
- Each channel's feed URL follows the pattern: `https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}`
- The generated combined feed can be served statically or pointed to from any RSS reader
