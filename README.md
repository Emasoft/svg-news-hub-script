# SVG News Hub - Local Script

Automated X/Twitter search and retweet script for the SVG News Hub.

## Overview

This script runs hourly on your Mac to:
1. Search X for "svg", "vector graphics", "vector animation"
2. Send discovered tweets to the Twin agent for review
3. Retweet agent-approved tweets via browser automation

## Requirements

- **uv** - Fast Python package manager (https://github.com/astral-sh/uv)
- macOS or Linux

## Quick Setup

```bash
# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Clone and setup
git clone https://github.com/Emasoft/svg-news-hub-script.git
cd svg-news-hub-script
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Create a virtual environment with `uv venv --python 3.12`
- Install dependencies (playwright, httpx)
- Install Playwright Chromium browser
- Set up an hourly cron job

## Manual Run

```bash
uv run python3 svg_news_hub.py
```

## Configuration

Edit svg_news_hub.py and update X_COOKIES with your values from Safari:
- Safari > Develop > Show Web Inspector > Storage > Cookies > x.com
- Copy: auth_token, ct0, kdt, twid

## Cron Setup (Manual)

```bash
crontab -e
# Add:
0 * * * * cd ~/svg-news-hub-script && uv run python3 svg_news_hub.py >> svg_news_hub.log 2>&1
```

## Logs

```bash
tail -f svg_news_hub.log
```
