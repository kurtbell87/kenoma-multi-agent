#!/usr/bin/env bash
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
tail -f "${PROJECT_DIR}/logs/"*.log 2>/dev/null || echo "No log files found yet. Start agents first."
