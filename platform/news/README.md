# RSS Platform

Self-hosted RSS aggregation using [FreshRSS](https://freshrss.org/) with PostgreSQL backend, deployed via Portainer.

## Architecture

```
compose.yaml          # FreshRSS + PostgreSQL stack
terraform/            # Portainer stack deployment
feeds.yaml            # Feed definitions and webhook actions
youtube-subscriptions.yaml  # YouTube channel tracking
youtube-subscriptions.opml  # Generated OPML for import
data/                 # Persistent volumes (gitignored)
```

## Deployment

```bash
# Via Terraform (Portainer)
cd terraform && terraform apply

# Or directly
docker compose up -d
```

## Feed Source Configuration Plan

FreshRSS supports native RSS/Atom feeds out of the box. For sources that don't provide feeds natively, use the strategies below.

### Direct RSS/Atom Sources

These work natively in FreshRSS — just add the feed URL:

| Source Type | Feed URL Pattern |
|-------------|-----------------|
| Blogs (WordPress, Ghost, Hugo) | `https://blog.example.com/feed/` or `/rss.xml` or `/index.xml` |
| GitHub releases | `https://github.com/{owner}/{repo}/releases.atom` |
| GitHub commits | `https://github.com/{owner}/{repo}/commits.atom` |
| Reddit subreddits | `https://www.reddit.com/r/{subreddit}/.rss` |
| Hacker News | `https://hnrss.org/frontpage` (or `/newest`, `/best`) |
| Stack Overflow tags | `https://stackoverflow.com/feeds/tag/{tag}` |
| ArXiv papers | `https://arxiv.org/rss/{category}` (e.g. `cs.AI`) |
| Mastodon accounts | `https://{instance}/@{user}.rss` |
| Substack newsletters | `https://{name}.substack.com/feed` |
| Medium publications | `https://medium.com/feed/{publication}` |
| DEV.to tags | `https://dev.to/feed/tag/{tag}` |
| Lobsters | `https://lobste.rs/rss` |

### YouTube Channels

YouTube provides native Atom feeds per channel:

```
https://www.youtube.com/feeds/videos.xml?channel_id={CHANNEL_ID}
```

Managed via `youtube-subscriptions.yaml` and the `/youtube` skill. The generated OPML file can be bulk-imported into FreshRSS.

To find a channel ID:
1. Visit the channel page → View Source → search `channelId`
2. Or use: `https://www.youtube.com/feeds/videos.xml?channel_id=` with the ID from the URL

### Websites Without Native Feeds

For sites that don't provide RSS, deploy an RSS bridge service:

**Option A: RSSHub (recommended for breadth)**

Add to compose.yaml:
```yaml
rsshub:
  image: diygod/rsshub:latest
  container_name: rsshub
  environment:
    - NODE_ENV=production
    - CACHE_TYPE=memory
  ports:
    - "1200:1200"
  restart: unless-stopped
```

RSSHub supports 1000+ sites including:
- Twitter/X timelines
- Instagram profiles
- Telegram channels
- Product Hunt
- App Store reviews
- NPM package updates
- Docker Hub image tags

Feed URL pattern: `http://rsshub:1200/{route}`

**Option B: RSS-Bridge (lightweight, self-contained)**

```yaml
rss-bridge:
  image: rssbridge/rss-bridge:latest
  container_name: rss-bridge
  ports:
    - "3000:80"
  restart: unless-stopped
```

Good for: Twitter, Instagram, Telegram, Bandcamp, and many others.

**Option C: FreshRSS HTML+XPath scraping (built-in)**

FreshRSS has a native HTML+XPath scraper for any webpage. Configure per-feed:
1. Add feed with the page URL
2. Set feed type to "HTML + XPath (website scraping)"
3. Define XPath selectors for: article container, title, link, content, date

### Podcast Feeds

Podcasts are standard RSS — add the feed URL directly. Find feeds via:
- Apple Podcasts: inspect the page for the feed link
- `https://podcasts.apple.com/lookup?id={ID}&entity=podcast` → `feedUrl`

### Newsletter-to-RSS

For email newsletters that don't offer RSS:

**Kill the Newsletter** (self-hosted):
```yaml
kill-the-newsletter:
  image: leafac/kill-the-newsletter:latest
  container_name: kill-the-newsletter
  environment:
    - URL=http://kill-the-newsletter:2525
  ports:
    - "2525:2525"
  restart: unless-stopped
```

Generates a unique email address per newsletter that converts to an Atom feed.

### Feed Organization Strategy

Organize feeds into FreshRSS categories:

| Category | Sources |
|----------|---------|
| Tech News | Hacker News, Lobsters, ArXiv, DEV.to |
| YouTube | All channels from `youtube-subscriptions.yaml` |
| GitHub | Release feeds for tracked projects |
| Blogs | Personal blogs, Substacks, Medium |
| Reddit | Curated subreddit feeds |
| Podcasts | Audio feed subscriptions |
| Newsletters | Via Kill the Newsletter bridge |
| Social | Mastodon, via RSSHub bridges |

### Automation & Webhooks

FreshRSS supports webhook actions on new articles (defined in `feeds.yaml`):
- Forward to n8n for workflow automation
- Send to Slack/Discord channels
- Trigger archival pipelines (Wallabag, Pocket)
- Push notifications via ntfy/Gotify

### Extensions

Useful FreshRSS extensions to install in `data/extensions/`:
- **YouTube/PeerTube** — embed video player in article view
- **CustomCSS** — theme customization
- **FilterTitle/FilterActions** — auto-tag/star based on keywords
- **Wallabag** — save articles for later reading

### Future Enhancements

- [ ] Add RSSHub to compose stack for non-RSS site coverage
- [ ] Import full YouTube OPML into FreshRSS categories
- [ ] Set up n8n webhook integration for feed-triggered automations
- [ ] Configure FreshRSS API for mobile reader apps (FeedMe, NetNewsWire)
- [ ] Add feed health monitoring (detect dead feeds)
