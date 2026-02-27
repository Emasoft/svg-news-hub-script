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

	WEB