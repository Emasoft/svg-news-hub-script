#!/usr/bin/env python3
"""
SVG News Hub - X/Twitter Search & Retweet Script
Runs hourly via cron. Fully automatic.
"""

import asyncio
import json
from datetime import datetime
from pathlib import Path

import httpx
from playwright.async_api import async_playwright

# === CONFIGURATION ===

SHEET_ID = "1swocAEQLeIORPqUKSHL_Gzoa2u8W7RBcr4ohuYvr3J0"
SHEET_API_URL = f"https://docs.google.com/spreadsheets/d/{SHEET_ID}/gviz/tq?tqx=out:json"

WEBHOOK_URL = "https://build.twin.so/triggers/05de01af-50e8-4aed-8c45-2ad11d91f972/webhook"

SEARCH_QUERIES = ["svg", "vector graphics", "vector animation"]
SCROLL_COUNT = 10

# X.com cookies - UPDATE THESE WITH YOUR VALUES
X_COOKIES = [
    {"name": "auth_token", "value": "YOUR_AUTH_TOKEN", "domain": ".x.com", "path": "/"},
    {"name": "ct0", "value": "YOUR_CT0", "domain": ".x.com", "path": "/"},
    {"name": "kdt", "value": "YOUR_KDT", "domain": ".x.com", "path": "/"},
    {"name": "twid", "value": "YOUR_TWID", "domain": ".x.com", "path": "/"},
]

PROCESSED_FILE = Path.home() / "svg-news-hub" / "processed_tweets.json"


def log(msg: str):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")


def load_processed() -> set:
    if PROCESSED_FILE.exists():
        with open(PROCESSED_FILE) as f:
            return set(json.load(f))
    return set()


def save_processed(processed: set):
    PROCESSED_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(PROCESSED_FILE, "w") as f:
        json.dump(list(processed), f)


def get_sheet_data() -> list:
    try:
        with httpx.Client(timeout=30) as client:
            resp = client.get(SHEET_API_URL)
            text = resp.text
            start = text.find("google.visualization.Query.setResponse(") + 39
            end = text.rfind(");")
            data = json.loads(text[start:end])
            cols = [c.get("label", "") for c in data["table"]["cols"]]
            rows = []
            for row in data["table"]["rows"]:
                values = [cell.get("v", "") if cell else "" for cell in row["c"]]
                rows.append(dict(zip(cols, values)))
            return rows
    except Exception as e:
        log(f"Error reading sheet: {e}")
        return []


def get_approved_tweets() -> list:
    return [r for r in get_sheet_data() if r.get("status") == "approved"]


def get_existing_tweet_ids() -> set:
    return {str(r.get("tweet_id", "")) for r in get_sheet_data() if r.get("tweet_id")}


async def send_to_webhook(tweets: list):
    if not tweets:
        return
    async with httpx.AsyncClient(timeout=30) as client:
        try:
            await client.post(WEBHOOK_URL, json={"action": "add_tweets", "tweets": tweets})
            log(f"Sent {len(tweets)} tweets to agent")
        except Exception as e:
            log(f"Webhook error: {e}")


async def update_status(tweet_id: str, status: str):
    async with httpx.AsyncClient(timeout=30) as client:
        try:
            await client.post(WEBHOOK_URL, json={"action": "update_status", "tweet_id": tweet_id, "status": status})
        except Exception as e:
            log(f"Status update error: {e}")


async def search_x(page, query: str) -> list:
    tweets = []
    url = f"https://x.com/search?q={query}&src=typed_query&f=live"
    try:
        await page.goto(url)
        await page.wait_for_timeout(3000)
    except Exception as e:
        log(f"Error loading search '{query}': {e}")
        return []
    
    seen = set()
    for _ in range(SCROLL_COUNT):
        elements = await page.query_selector_all('article[data-testid="tweet"]')
        for el in elements:
            try:
                link = await el.query_selector('a[href*="/status/"]')
                if not link:
                    continue
                href = await link.get_attribute("href")
                tweet_id = href.split("/status/")[-1].split("?")[0].split("/")[0]
                if tweet_id in seen or not tweet_id.isdigit():
                    continue
                seen.add(tweet_id)
                
                author_el = await el.query_selector('div[data-testid="User-Name"] a')
                author = ""
                if author_el:
                    author_href = await author_el.get_attribute("href")
                    if author_href:
                        author = author_href.strip("/").split("/")[0]
                
                text_el = await el.query_selector('div[data-testid="tweetText"]')
                text = await text_el.inner_text() if text_el else ""
                
                time_el = await el.query_selector("time")
                timestamp = await time_el.get_attribute("datetime") if time_el else ""
                
                tweet_url = f"https://x.com{href}" if href.startswith("/") else href
                tweets.append({
                    "tweet_id": tweet_id,
                    "tweet_url": tweet_url,
                    "author_username": author,
                    "text": text[:500],
                    "timestamp": timestamp,
                    "search_query": query,
                    "submitted_at": datetime.utcnow().isoformat(),
                    "status": "pending"
                })
            except Exception:
                continue
        await page.evaluate("window.scrollBy(0, 1000)")
        await page.wait_for_timeout(1500)
    return tweets


async def retweet(page, tweet_url: str) -> bool:
    try:
        await page.goto(tweet_url)
        await page.wait_for_timeout(2500)
        btn = await page.query_selector('button[data-testid="retweet"]')
        if not btn:
            log("  No retweet button")
            return False
        await btn.click()
        await page.wait_for_timeout(800)
        confirm = await page.query_selector('div[data-testid="retweetConfirm"]')
        if confirm:
            await confirm.click()
            await page.wait_for_timeout(1500)
            return True
        log("  No confirm button")
        return False
    except Exception as e:
        log(f"  Retweet error: {e}")
        return False


async def main():
    log("=" * 50)
    log("SVG News Hub - Starting")
    log("=" * 50)
    
    processed = load_processed()
    existing_ids = get_existing_tweet_ids()
    log(f"Existing tweets in sheet: {len(existing_ids)}")
    log(f"Locally processed: {len(processed)}")
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport={"width": 1280, "height": 800},
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        )
        await context.add_cookies(X_COOKIES)
        page = await context.new_page()
        
        # Step 1: Retweet approved tweets
        approved = get_approved_tweets()
        log(f"Approved tweets to retweet: {len(approved)}")
        for tweet in approved:
            tweet_id = str(tweet.get("tweet_id", ""))
            tweet_url = tweet.get("tweet_url", "")
            if tweet_id in processed:
                continue
            log(f"Retweeting: {tweet_url}")
            if await retweet(page, tweet_url):
                await update_status(tweet_id, "retweeted")
                processed.add(tweet_id)
                log("  Done")
            else:
                log("  Failed")
            await page.wait_for_timeout(3000)
        
        # Step 2: Search for new tweets
        all_tweets = []
        for query in SEARCH_QUERIES:
            log(f"Searching: '{query}'")
            tweets = await search_x(page, query)
            new_tweets = [t for t in tweets if t["tweet_id"] not in existing_ids]
            all_tweets.extend(new_tweets)
            log(f"  Found {len(tweets)}, {len(new_tweets)} new")
            await page.wait_for_timeout(2000)
        
        # Dedupe
        seen = set()
        unique = []
        for t in all_tweets:
            if t["tweet_id"] not in seen:
                seen.add(t["tweet_id"])
                unique.append(t)
        log(f"Total new unique: {len(unique)}")
        
        # Step 3: Send to agent
        if unique:
            await send_to_webhook(unique)
        
        await browser.close()
    
    save_processed(processed)
    log("Done")
    log("=" * 50)


if __name__ == "__main__":
    asyncio.run(main())
