#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export IBKR_WEB_ROOT="${IBKR_WEB_ROOT:-$(cd ../web && pwd)}"
swift run IBKRAnalyticsStudioMac
