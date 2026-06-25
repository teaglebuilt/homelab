# YouTube Subscriptions YAML Schema

## Initial file structure

When creating `youtube-subscriptions.yaml` for the first time:

```yaml
# YouTube Subscriptions
# Managed by the /youtube skill
# Each channel's RSS feed: https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}

feed_metadata:
  title: "My YouTube Subscriptions Feed"
  description: "Aggregated feed from YouTube channels I follow"
  author: ""                    # user's name, optional
  site_url: ""                  # if hosted somewhere, optional
  last_updated: ""              # auto-populated on generate

channels:
  - name: "Example Channel"
    channel_id: "UCxxxxxxxxxxxxxxxxxxxxxxxx"
    handle: "@example"
    tags: [example]
    added: "2026-02-17"
    notes: ""
```

## Field reference

### feed_metadata

| Field         | Required | Description                                     |
|---------------|----------|-------------------------------------------------|
| title         | yes      | Title for the generated combined RSS feed       |
| description   | no       | Subtitle/description for the feed               |
| author        | no       | Feed author name                                |
| site_url      | no       | URL where the feed is hosted                    |
| last_updated  | auto     | ISO timestamp, set by the generate script       |

### channels[]

| Field      | Required | Description                                           |
|------------|----------|-------------------------------------------------------|
| name       | yes      | Display name of the YouTube channel                   |
| channel_id | yes      | YouTube channel ID (starts with UC, 24 chars)         |
| handle     | no       | YouTube handle (e.g., @mkbhd)                         |
| tags       | no       | List of user-defined category tags                    |
| added      | no       | Date the subscription was added (YYYY-MM-DD)          |
| notes      | no       | Free-text notes about the channel                     |

## Validation rules

- `channel_id` must start with `UC` and be 24 characters long
- `name` must be non-empty
- No duplicate `channel_id` values
- `tags` should be lowercase, hyphenated (e.g., `machine-learning`, `devops`)
