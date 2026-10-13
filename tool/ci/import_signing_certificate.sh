#!/usr/bin/env bash
#
# Puts the Developer ID certificate into a throwaway keychain so that
# tool/release_macos.sh finds it by name, exactly as it does on a developer's
# machine — the point being that the release script stays unaware it is in CI.
#
# A temporary keychain rather than the login one: a runner is destroyed after the
# job, and nothing else on it needs a signing identity.
#
# Expects, from repository secrets:
#   CERT           base64 of the exported .p12
#   CERT_PASSWORD  the .p12 export password
set -euo pipefail

: "${CERT:?nothing in CERT}"
: "${CERT_PASSWORD:?nothing in CERT_PASSWORD}"
: "${RUNNER_TEMP:?not running on a GitHub runner}"

# Generated, not configured. This protects a keychain that exists for one job on
# a machine that is destroyed afterwards, and it never leaves this script -- the
# keychain is left unlocked for the steps that follow. Asking a human to invent
# and store it would be security theatre.
KEYCHAIN_PASSWORD="$(uuidgen)"
readonly KEYCHAIN_PASSWORD

# Shared with store_notary_credentials.sh, which writes into the same keychain.
readonly KEYCHAIN="$RUNNER_TEMP/signing.keychain-db"
readonly CERT_FILE="$RUNNER_TEMP/certificate.p12"

trap 'rm -f "$CERT_FILE"' EXIT

printf '%s' "$CERT" | base64 --decode >"$CERT_FILE"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
# No idle lock: a notarisation round trip takes longer than the default timeout,
# and a locked keychain mid-build fails in a way that reads like a bad password.
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

# -T grants codesign access to the key; the partition list is what actually makes
# that stick without a UI prompt on modern macOS.
security import "$CERT_FILE" -k "$KEYCHAIN" -P "$CERT_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

# Both lists, because they answer different questions: `security find-identity`
# — which the release script's preflight uses — reads the search list, while
# xcodebuild signs out of the default keychain.
existing="$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')"
# shellcheck disable=SC2086 # deliberate word splitting: one argument per keychain
security list-keychains -d user -s "$KEYCHAIN" $existing
security default-keychain -s "$KEYCHAIN"

echo 'Identities now available:'
security find-identity -v -p codesigning
