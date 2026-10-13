#!/usr/bin/env bash
#
# Stores App Store Connect API credentials under the keychain profile that
# tool/release_macos.sh looks for, so that script notarises in CI unmodified.
#
# An API key rather than an app-specific password because it survives a password
# change and is not tied to a person's Apple ID — which is what the README
# already says a runner would want.
#
# Run after import_signing_certificate.sh: it writes into the same keychain, and
# the release script reads the profile out of the default one.
#
# Expects, from repository secrets:
#   APPLE_API_KEY_P8     contents of AuthKey_XXXXXXXXXX.p8
#   APPLE_API_KEY_ID
#   APPLE_API_ISSUER_ID
#   NOTARY_PROFILE       optional; must match what release_macos.sh expects
set -euo pipefail

: "${APPLE_API_KEY_P8:?nothing in APPLE_API_KEY_P8}"
: "${APPLE_API_KEY_ID:?nothing in APPLE_API_KEY_ID}"
: "${APPLE_API_ISSUER_ID:?nothing in APPLE_API_ISSUER_ID}"
: "${RUNNER_TEMP:?not running on a GitHub runner}"

readonly KEYCHAIN="$RUNNER_TEMP/signing.keychain-db"
readonly PROFILE="${NOTARY_PROFILE:-time-log-notary}"
readonly KEY_FILE="$RUNNER_TEMP/AuthKey.p8"

trap 'rm -f "$KEY_FILE"' EXIT

printf '%s' "$APPLE_API_KEY_P8" >"$KEY_FILE"

xcrun notarytool store-credentials "$PROFILE" \
  --key "$KEY_FILE" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --keychain "$KEYCHAIN"

echo "notary profile '$PROFILE' stored"
