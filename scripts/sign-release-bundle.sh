#!/usr/bin/env bash
# Signs GhDashboard.app for distribution. With MACOS_CERTIFICATE_BASE64 set, uses
# Developer ID Application + hardened runtime and notarizes (when notary creds are set).
# Otherwise falls back to ad-hoc signing (Gatekeeper warns on first open).
set -euo pipefail

KEYCHAIN=""
KEY_P8=""
P12_TMP=""

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="GhDashboard.app"

cleanup() {
  if [[ -n "${KEYCHAIN}" && -f "${KEYCHAIN}" ]]; then
    security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  fi
  if [[ -n "${KEY_P8}" && -f "${KEY_P8}" ]]; then
    rm -f "$KEY_P8"
  fi
  if [[ -n "${P12_TMP}" && -f "${P12_TMP}" ]]; then
    rm -f "$P12_TMP"
  fi
}
trap cleanup EXIT

sign_adhoc() {
  echo "No Developer ID certificate in env: using ad-hoc signature."
  echo "Users will see a Gatekeeper warning until they use Right-click → Open (first launch only)."
  codesign --force --sign - "$APP"
}

if [[ -z "${MACOS_CERTIFICATE_BASE64:-}" ]]; then
  sign_adhoc
  exit 0
fi

P12_TMP="${RUNNER_TEMP:-/tmp}/devid-signing.p12"
echo "$MACOS_CERTIFICATE_BASE64" | base64 --decode > "$P12_TMP"

KEYCHAIN="${RUNNER_TEMP:-/tmp}/build-signing.keychain-db"
KEYCHAIN_PWD="$(openssl rand -base64 32)"
security create-keychain -p "$KEYCHAIN_PWD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PWD" "$KEYCHAIN"
security import "$P12_TMP" -k "$KEYCHAIN" -P "${MACOS_CERTIFICATE_PASSWORD:-}" -T /usr/bin/codesign -T /usr/bin/security
security list-keychain -d user -s "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PWD" "$KEYCHAIN"

IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | awk -F'"' '/Developer ID Application/ { print $2; exit }')"
if [[ -z "$IDENTITY" ]]; then
  echo "error: no Developer ID Application identity in imported keychain" >&2
  exit 1
fi
echo "Signing with: $IDENTITY"

# Deep signing covers embedded Swift/SPM runtimes and resources.
codesign --force --sign "$IDENTITY" --options runtime --timestamp --deep "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

ZIP_NOTARY="${RUNNER_TEMP:-/tmp}/GhDashboard-notarize.zip"
rm -f "$ZIP_NOTARY"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP_NOTARY"

NOTARIZE_OK=0
if [[ -n "${APP_STORE_CONNECT_API_KEY_B64:-}" && -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ]]; then
  KEY_P8="${RUNNER_TEMP:-/tmp}/AuthKey.p8"
  echo "$APP_STORE_CONNECT_API_KEY_B64" | base64 --decode > "$KEY_P8"
  chmod 600 "$KEY_P8"
  echo "Submitting to Apple Notary Service (API key)…"
  xcrun notarytool submit "$ZIP_NOTARY" \
    --key "$KEY_P8" \
    --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
    --wait
  NOTARIZE_OK=1
elif [[ -n "${APPLE_ID:-}" && -n "${NOTARY_APP_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  echo "Submitting to Apple Notary Service (Apple ID)…"
  xcrun notarytool submit "$ZIP_NOTARY" \
    --apple-id "$APPLE_ID" \
    --password "$NOTARY_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
  NOTARIZE_OK=1
fi

if [[ "$NOTARIZE_OK" -eq 1 ]]; then
  xcrun stapler staple "$APP"
  echo "Notarization staple applied to $APP"
else
  echo "warning: Developer ID sign succeeded but notarization was skipped (missing API key or Apple ID credentials)."
  echo "warning: Users may still see Gatekeeper prompts without stapling. Add notary secrets — see README."
fi
