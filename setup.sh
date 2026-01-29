#!/bin/bash
set -e

DIR="$HOME/svg-news-hub"
echo "=== SVG News Hub Setup ==="

mkdir -p "$DIR"
echo "Created $DIR"

if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 not found"
    exit 1
fi

echo "Installing dependencies..."
pip3 install --quiet playwright httpx
python3 -m playwright install chromium
echo "Dependencies installed"

if [ -f "svg_news_hub.py" ]; then
    cp svg_news_hub.py "$DIR/"
    echo "Script copied to $DIR"
fi

CRON_CMD="0 * * * * cd $DIR && python3 svg_news_hub.py >> svg_news_hub.log 2>&1"
(crontab -l 2>/dev/null | grep -v "svg_news_hub"; echo "$CRON_CMD") | crontab -
echo "Cron job added (hourly)"

echo ""
echo "=== Setup Complete ==="
echo "Script: $DIR/svg_news_hub.py"
echo "Logs: $DIR/svg_news_hub.log"
echo ""
echo "IMPORTANT: Edit $DIR/svg_news_hub.py and update X_COOKIES with your values"
echo "Test with: python3 $DIR/svg_news_hub.py"
