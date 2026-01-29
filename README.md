# SVG News Hub - Local Script

Automated X/Twitter search and retweet script for the SVG News Hub.

## Overview

This script runs hourly on your Mac to:
1. Search X for "svg", "vector graphics", "vector animation"
2. Send discovered tweets to the Twin agent for review
3. Retweet agent-approved tweets via browser automation

## Requirements

- Python 3.9+
- macOS or Linux

## Quick Setup

```bash
git clone https://github.com/Emasoft/svg-news-hub-script.git
cd svg-news-hub-script
chmod +x setup.sh
./setup.sh
```

## Manual Setup

```bash
pip install playwright httpx
playwright install chromium
python3 svg_news_hub.py
```

## Configuration

Edit svg_news_hub.py and update X_COOKIES with your values from Safari:
- Safari > Develop > Show Web Inspector > Storage > Cookies > x.com
- Copy: auth_token, ct0, kdt, twid

## Cron Setup

```bash
crontab -e
# Add:
0 * * * * cd ~/svg-news-hub && python3 svg_news_hub.py >> svg_news_hub.log 2>&1
```

## Logs

```bash
tail -f ~/svg-news-hub/svg_news_hub.log
```
