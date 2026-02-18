#!/bin/bash
set -e

AUTH_TOKEN="YOUR_AUTH_TOKEN_HERE"
CT0="YOUR_CT0_HERE"
KDT="YOUR_KDT_HERE"
TWID="YOUR_TWID_HERE"

INSTALL_DIR="$HOME/svg-news-hub-script"
WEBHOOK_URL="https://build.twin.so/triggers/05de01af-50e8-4aed-8c45-2ad11d91f972/webhook"
SHEET_URL="https://docs.google.com/spreadsheets/d/1swocAEQLeIORPqUKSHL_Gzoa2u8W7RBcr4ohuYvr3J0"

echo "=== SVG News Hub - Complete Installer ==="

if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed."
    echo "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

cat > "$INSTALL_DIR/svg_news_hub.py" << 'PYTHON_EOF'
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path
import httpx
from playwright.sync_api import sync_playwright

X_COOKIES = {
    "auth_token": "AUTH_TOKEN_PLACEHOLDER",
    "ct0": "CT0_PLACEHOLDER",
    "kdt": "KDT_PLACEHOLDER",
    "twid": "TWID_PLACEHOLDER",
}

WEBHOOK_URL = "WEBHOOK_URL_PLACEHOLDER"
SHEET_URL = "SHEET_URL_PLACEHOLDER"
SEARCH_QUERIES = ["svg", "vector graphics", "vector animation", "lottie animation"]

log_file = Path(__file__).parent / "svg_news_hub.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(log_file), logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

def check_cookie_expiry():
    expiry_date = datetime(2026, 2, 5, tzinfo=timezone.utc)
    days_left = (expiry_date - datetime.now(timezone.utc)).days
    if days_left <= 0:
        logger.error("X COOKIES HAVE EXPIRED!")
        return False
    elif days_left <= 7:
        logger.warning(f"X cookies expire in {days_left} days!")
    return True

def search_twitter(query, max_results=20):
    tweets = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 800}, user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")
        cookies = [
            {"name": "auth_token", "value": X_COOKIES["auth_token"], "domain": ".x.com", "path": "/"},
            {"name": "ct0", "value": X_COOKIES["ct0"], "domain": ".x.com", "path": "/"},
            {"name": "kdt", "value": X_COOKIES["kdt"], "domain": ".x.com", "path": "/"},
            {"name": "twid", "value": X_COOKIES["twid"], "domain": ".x.com", "path": "/"},
        ]
        context.add_cookies(cookies)
        page = context.new_page()
        try:
            search_url = f"https://x.com/search?q={query}&src=typed_query&f=live"
            logger.info(f"Searching Twitter for: {query}")
            page.goto(search_url, wait_until="networkidle", timeout=30000)
            page.wait_for_selector('article[data-testid="tweet"]', timeout=15000)
            tweet_elements = page.query_selector_all('article[data-testid="tweet"]')
            for element in tweet_elements[:max_results]:
                try:
                    tweet_link = element.query_selector('a[href*="/status/"]')
                    if not tweet_link:
                        continue
                    tweet_url = "https://x.com" + tweet_link.get_attribute("href")
                    tweet_id = tweet_url.split("/status/")[-1].split("?")[0]
                    author_elem = element.query_selector('div[data-testid="User-Name"] a')
                    author = author_elem.get_attribute("href").strip("/") if author_elem else "unknown"
                    text_elem = element.query_selector('div[data-testid="tweetText"]')
                    text = text_elem.inner_text() if text_elem else ""
                    time_elem = element.query_selector("time")
                    timestamp = time_elem.get_attribute("datetime") if time_elem else None
                    tweets.append({"tweet_id": tweet_id, "tweet_url": tweet_url, "author_username": author, "text": text[:500], "timestamp": timestamp, "search_query": query, "submitted_at": datetime.now(timezone.utc).isoformat()})
                except Exception as e:
                    logger.warning(f"Error extracting tweet: {e}")
        except Exception as e:
            logger.error(f"Error searching Twitter: {e}")
        finally:
            browser.close()
    logger.info(f"Found {len(tweets)} tweets for query: {query}")
    return tweets

def send_to_webhook(tweets):
    if not tweets:
        return True
    try:
        logger.info(f"Sending {len(tweets)} tweets to webhook...")
        response = httpx.post(WEBHOOK_URL, json={"tweets": tweets}, timeout=30.0, headers={"Content-Type": "application/json"})
        response.raise_for_status()
        return True
    except Exception as e:
        logger.error(f"Failed to send to webhook: {e}")
        return False

def get_approved_tweets():
    try:
        csv_url = SHEET_URL.replace("/view", "/export?format=csv")
        response = httpx.get(csv_url, timeout=30.0, follow_redirects=True)
        response.raise_for_status()
        lines = response.text.strip().split("\n")
        if len(lines) <= 1:
            return []
        headers = lines[0].split(",")
        approved = []
        for line in lines[1:]:
            values = line.split(",")
            row = dict(zip(headers, values))
            if row.get("status", "").lower() == "approved":
                approved.append(row)
        return approved
    except Exception as e:
        logger.error(f"Failed to fetch approved tweets: {e}")
        return []

def retweet(tweet_url):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 800}, user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")
        cookies = [
            {"name": "auth_token", "value": X_COOKIES["auth_token"], "domain": ".x.com", "path": "/"},
            {"name": "ct0", "value": X_COOKIES["ct0"], "domain": ".x.com", "path": "/"},
            {"name": "kdt", "value": X_COOKIES["kdt"], "domain": ".x.com", "path": "/"},
            {"name": "twid", "value": X_COOKIES["twid"], "domain": ".x.com", "path": "/"},
        ]
        context.add_cookies(cookies)
        page = context.new_page()
        try:
            logger.info(f"Retweeting: {tweet_url}")
            page.goto(tweet_url, wait_until="networkidle", timeout=30000)
            retweet_button = page.wait_for_selector('button[data-testid="retweet"]', timeout=10000)
            retweet_button.click()
            page.wait_for_selector('div[data-testid="retweetConfirm"]', timeout=5000)
            page.click('div[data-testid="retweetConfirm"]')
            page.wait_for_timeout(2000)
            logger.info(f"Retweeted: {tweet_url}")
            return True
        except Exception as e:
            logger.error(f"Failed to retweet {tweet_url}: {e}")
            return False
        finally:
            browser.close()

def main():
    logger.info("=" * 60)
    logger.info("SVG News Hub - Starting run")
    logger.info("=" * 60)
    if not check_cookie_expiry():
        return
    all_tweets = []
    for query in SEARCH_QUERIES:
        tweets = search_twitter(query, max_results=10)
        all_tweets.extend(tweets)
    seen_ids = set()
    unique_tweets = []
    for tweet in all_tweets:
        if tweet["tweet_id"] not in seen_ids:
            seen_ids.add(tweet["tweet_id"])
            unique_tweets.append(tweet)
    logger.info(f"Total unique tweets found: {len(unique_tweets)}")
    if unique_tweets:
        send_to_webhook(unique_tweets)
    approved = get_approved_tweets()
    for tweet in approved:
        tweet_url = tweet.get("tweet_url")
        if tweet_url:
            retweet(tweet_url)
    logger.info("SVG News Hub - Run complete")

if __name__ == "__main__":
    main()
PYTHON_EOF

sed -i '' "s|AUTH_TOKEN_PLACEHOLDER|$AUTH_TOKEN|g" "$INSTALL_DIR/svg_news_hub.py"
sed -i '' "s|CT0_PLACEHOLDER|$CT0|g" "$INSTALL_DIR/svg_news_hub.py"
sed -i '' "s|KDT_PLACEHOLDER|$KDT|g" "$INSTALL_DIR/svg_news_hub.py"
sed -i '' "s|TWID_PLACEHOLDER|$TWID|g" "$INSTALL_DIR/svg_news_hub.py"
sed -i '' "s|WEBHOOK_URL_PLACEHOLDER|$WEBHOOK_URL|g" "$INSTALL_DIR/svg_news_hub.py"
sed -i '' "s|SHEET_URL_PLACEHOLDER|$SHEET_URL|g" "$INSTALL_DIR/svg_news_hub.py"

echo "Creating venv..."
uv venv --python 3.12
echo "Installing dependencies..."
uv pip install playwright httpx
echo "Installing Chromium..."
uv run playwright install chromium

PLIST_NAME="com.svgnewshub.agent"
PLIST_PATH="$HOME/Library/LaunchAgents/\${PLIST_NAME}.plist"
LOG_PATH="$INSTALL_DIR/svg_news_hub.log"
UV_PATH="$(which uv)"

cat > "$PLIST_PATH" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>\${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>\${UV_PATH}</string>
        <string>run</string>
        <string>python3</string>
        <string>\${INSTALL_DIR}/svg_news_hub.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>\${INSTALL_DIR}</string>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>\${LOG_PATH}</string>
    <key>StandardErrorPath</key>
    <string>\${LOG_PATH}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:\${HOME}/.local/bin</string>
    </dict>
</dict>
</plist>
PLIST_EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "=== SETUP COMPLETE ==="
echo "Test: cd $INSTALL_DIR && uv run python3 svg_news_hub.py"
echo "Logs: tail -f $INSTALL_DIR/svg_news_hub.log"
echo "Cookies expire: Feb 5, 2026"