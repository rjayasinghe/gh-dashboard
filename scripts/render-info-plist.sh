#!/usr/bin/env bash
# Renders Info.plist from the template. Usage:
#   render-info-plist.sh <output-path> [marketing-version] [build-number]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/Sources/GhDashboard/Resources/Info.plist.template"
OUT="${1:?output path required}"
MARKETING_VERSION="${2:-1.0.0}"
BUILD_NUMBER="${3:-$MARKETING_VERSION}"

sed \
  -e "s/__MARKETING_VERSION__/${MARKETING_VERSION}/g" \
  -e "s/__BUILD_NUMBER__/${BUILD_NUMBER}/g" \
  "$TEMPLATE" > "$OUT"
