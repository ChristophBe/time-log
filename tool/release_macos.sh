#!/usr/bin/env bash
#
# Builds, signs, notarises and packages the macOS app for direct distribution
# (Developer ID, not the App Store). The result is build/release/time-log-<version>.dmg,
# which opens on any Mac with no Gatekeeper warning.
#
# One-time setup per machine, before the first run:
#
#   xcrun notarytool store-credentials time-log-notary \
#     --key ~/private_keys/AuthKey_XXXXXXXXXX.p8 \
#     --key-id XXXXXXXXXX \
#     --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# Overridable:
#   SIGNING_IDENTITY   code-signing identity (default: this project's Developer ID)
#   NOTARY_PROFILE     notarytool keychain profile (default: time-log-notary)
#   SKIP_NOTARIZE=1    build, sign and package only — for checking the signing setup
#                      without spending two round trips to Apple
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Christoph Becker (X5HR67U389)}"
readonly NOTARY_PROFILE="${NOTARY_PROFILE:-time-log-notary}"
readonly SKIP_NOTARIZE="${SKIP_NOTARIZE:-}"

readonly APP_NAME="Time Log"
readonly VOLUME_NAME="Time Log"
readonly BUILT_APP="$REPO_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"
readonly OUT_DIR="$REPO_ROOT/build/release"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# Everything Apple needs from us, checked before the build rather than after it.
preflight() {
  step 'Preflight'

  security find-identity -v -p codesigning | grep -qF "$SIGNING_IDENTITY" \
    || fail "no code-signing identity '$SIGNING_IDENTITY' in the keychain.
       Available:
$(security find-identity -v -p codesigning)"
  echo "identity:    $SIGNING_IDENTITY"

  if [[ -n "$SKIP_NOTARIZE" ]]; then
    echo 'notarising:  skipped (SKIP_NOTARIZE is set)'
    return
  fi

  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "no notarytool credentials stored under the profile '$NOTARY_PROFILE'.
       Create them once with 'xcrun notarytool store-credentials $NOTARY_PROFILE …';
       see the header of this script."
  echo "notary:      $NOTARY_PROFILE"
}

# Submits one artefact and waits. A rejection is useless without the log, so fetch it.
notarize() {
  local artefact="$1" label="$2"
  local response="$OUT_DIR/notary-$label.json"
  local id status

  xcrun notarytool submit "$artefact" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format json >"$response" || true

  id="$(plutil -extract id raw -o - "$response" 2>/dev/null || true)"
  status="$(plutil -extract status raw -o - "$response" 2>/dev/null || true)"

  if [[ "$status" != 'Accepted' ]]; then
    echo "notarisation of $label came back '${status:-unknown}'" >&2
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fail "notarisation failed; the log above says why (full response: $response)"
  fi
  echo "accepted (submission $id)"
}

main() {
  cd "$REPO_ROOT"
  preflight

  local version
  version="$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)"
  [[ -n "$version" ]] || fail 'could not read version from pubspec.yaml'

  step "Building $APP_NAME $version (release)"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
  # Signing happens during the build: the Release configuration carries the Developer ID
  # identity and the hardened runtime, and Xcode signs the embedded frameworks with it.
  flutter build macos --release
  [[ -d "$BUILT_APP" ]] || fail "expected an app bundle at $BUILT_APP"

  step 'Verifying the signature'
  codesign --verify --deep --strict --verbose=2 "$BUILT_APP"
  local signature
  signature="$(codesign --display --verbose=4 "$BUILT_APP" 2>&1)"
  grep -E 'Authority|flags|TeamIdentifier' <<<"$signature"
  # Hardened runtime is what notarisation requires; catch its absence here, not after a
  # round trip to Apple. The flags only show up at --verbose=4, hence the capture above.
  grep -q 'flags=.*runtime' <<<"$signature" \
    || fail 'the app is not built with the hardened runtime (ENABLE_HARDENED_RUNTIME)'
  # Notarisation rejects anything a debugger could attach to, and Xcode injects that
  # entitlement unless told not to. Cheaper to notice here than in a rejection log.
  if codesign --display --entitlements - --xml "$BUILT_APP" 2>/dev/null \
       | grep -q 'get-task-allow'; then
    fail 'the app carries com.apple.security.get-task-allow, which notarisation rejects
       (CODE_SIGN_INJECT_BASE_ENTITLEMENTS must be NO for Release)'
  fi
  # A secure timestamp, countersigned by Apple, not the local `Signed Time` that a plain
  # `xcodebuild build` records. Notarisation rejects the latter.
  grep -qE '^Timestamp=' <<<"$signature" \
    || fail 'the signature has no secure timestamp, which notarisation rejects
       (OTHER_CODE_SIGN_FLAGS must carry --timestamp for Release)'
  echo "architectures: $(lipo -archs "$BUILT_APP/Contents/MacOS/$APP_NAME")"

  local app="$OUT_DIR/$APP_NAME.app"
  ditto "$BUILT_APP" "$app"

  if [[ -z "$SKIP_NOTARIZE" ]]; then
    step 'Notarising the app'
    # Stapling the .app itself, not just the disk image, is what lets a first launch
    # succeed on a Mac that is offline.
    local zip="$OUT_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$app" "$zip"
    notarize "$zip" 'app'
    xcrun stapler staple "$app"
    rm -f "$zip"
  fi

  step 'Building the disk image'
  local stage="$OUT_DIR/stage" dmg="$OUT_DIR/time-log-$version.dmg"
  rm -rf "$stage"
  mkdir -p "$stage"
  ditto "$app" "$stage/$APP_NAME.app"
  ln -s /Applications "$stage/Applications"
  hdiutil create -volname "$VOLUME_NAME" -srcfolder "$stage" -format UDZO -ov "$dmg" >/dev/null
  rm -rf "$stage"
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$dmg"

  if [[ -z "$SKIP_NOTARIZE" ]]; then
    step 'Notarising the disk image'
    notarize "$dmg" 'dmg'
    xcrun stapler staple "$dmg"

    step 'Final checks'
    spctl --assess --type execute --verbose "$app"
    xcrun stapler validate "$dmg"
  fi

  printf '\n\033[1mDone.\033[0m %s\n' "$dmg"
  [[ -n "$SKIP_NOTARIZE" ]] && printf 'Not notarised — other Macs will warn on first open.\n'
  return 0
}

main "$@"
