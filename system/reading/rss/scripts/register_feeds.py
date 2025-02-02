import os
import yaml
import requests

# 🔵 RSSHub generates the feed URL
RSSHUB_BASE = "http://rsshub.local:1200"

# 🔴 FreshRSS API where feeds are registered
FRESHRSS_API = "http://freshrss.local/api/greader.php"
USERNAME = os.environ["FRESH_RSS_USERNAME"]
PASSWORD = os.environ["FRESH_RSS_PASSWORD"]


auth_response = requests.post(f"{FRESHRSS_API}/login", data={"email": USERNAME, "password": PASSWORD})
if auth_response.status_code == 200:
    token = auth_response.json().get("token")
else:
    print("Authentication failed")
    exit(1)

headers = {"Authorization": f"Bearer {token}"}


def load_feeds():
    with open("/scripts/feeds.yaml", "r") as file:
        feeds = yaml.safe_load(file)["feeds"]

    for feed in feeds:
        # 🔵 Generate the full RSSHub feed URL
        rss_url = f"{RSSHUB_BASE}/{feed['route']}"

        # 🔴 Register the RSS feed in FreshRSS
        response = requests.post(f"{FRESHRSS_API}/subscriptions/add", headers=headers, json={"url": rss_url})
        print(f"Added: {feed['name']} - {rss_url} - Status: {response.status_code}")


if __name__ == "__main__":
    load_feeds()