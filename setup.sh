#!/bin/bash
set -e

echo "=== SVG News Hub Script Setup (using uv) ==="

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed. Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Create venv with Python 3.12
echo "Creating virtual environment with Python 3.12..."
uv venv --python 3.12

# Install dependencies
echo "Installing dependencies..."
uv pip install playwright httpx

# Install Playwright browsers
echo "Installing Playwright Chromium browser..."
uv run playwright install chromium

# Setup cron job (hourly)
echo "Setting up hourly cron job..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRON_CMD="0 * * * * cd $SCRIPT_DIR && uv run python3 svg_news_hub.py >> svg_news_hub.log 2>&1"

# Check if cron job already exists
(crontab -l 2>/dev/null | grep -v "svg_news_hub.py"; echo "$CRON_CMD") | crontab -

echo ""
echo "=== Setup Complete ==="
echo "The script will run every hour via cron."
echo ""
echo "To test manually: uv run python3 svg_news_hub.py"
echo "To view logs: tail -f svg_news_hub.log"
