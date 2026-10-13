#!/usr/bin/env bash
#
# Puts the five secrets the notarised macOS release needs into the GitHub
# repository, so setting CI up is one command instead of six web forms.
#
# Nothing sensitive is ever an argument. The certificate and the API key come
# from files you point at; the export password comes from a prompt that does not
# echo; and every value reaches `gh` on stdin. So none of it lands in your shell
# history, in `ps` output, or in this script's own trace if you run it with -x.
#
#   ./tool/ci/set_secrets.sh
#   ./tool/ci/set_secrets.sh --repo OWNER/REPO
#
# Needs `gh`, authenticated with a token that can write repository secrets, and
# `openssl` to check the certificate before uploading it. Re-running is safe:
# setting a secret replaces it.
#
# Only the macOS release needs any of this. Every other CI job -- the gates, all
# six platform builds, the integration suite -- runs with no secrets at all.
set -euo pipefail

REPO=''

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
note() { printf '  %s\n' "$1"; }

# The header comment is the documentation, so print that rather than keeping a
# second copy of it in sync by hand.
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' \
    "${BASH_SOURCE[0]}"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 || fail '--repo needs OWNER/REPO' ;;
    -h|--help) usage ;;
    *) fail "unknown argument '$1' (try --help)" ;;
  esac
done

# Prompts set ANSWER instead of printing, because `fail` inside a `$(...)`
# would only kill the subshell: the script would carry on with an empty value,
# and the retry loop below would spin forever on a redirected stdin. Two
# separate afternoons have been lost to that shape of bug; it stays written down.
ANSWER=''

ask() {
  ANSWER=''
  read -r -p "$1" ANSWER || fail 'no more input; nothing was changed'
}

ask_file() {
  while :; do
    ask "$1"
    # A leading ~ is not expanded in something typed at a prompt, which is
    # exactly how people type a path to a key in their home directory.
    [[ "$ANSWER" == '~'* ]] && ANSWER="$HOME${ANSWER:1}"
    [[ -z "$ANSWER" ]] && { printf '  (required)\n' >&2; continue; }
    [[ -f "$ANSWER" ]] || { printf '  no file at %s\n' "$ANSWER" >&2; continue; }
    return
  done
}

preflight() {
  step 'Preflight'
  command -v gh >/dev/null || fail 'gh is not installed (brew install gh)'
  command -v openssl >/dev/null || fail 'openssl is not installed'
  # shellcheck disable=SC2016 # the backticks are prose, not a substitution
  gh auth status >/dev/null 2>&1 \
    || fail 'gh is not authenticated; run `gh auth login`'

  if [[ -z "$REPO" ]]; then
    REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" \
      || fail 'not in a GitHub repository; pass --repo OWNER/REPO'
  fi
  readonly REPO
  note "repository:  $REPO"

  # Writing secrets needs more than reading them, and finding that out after the
  # prompts would mean typing a password for nothing.
  gh secret list --repo "$REPO" >/dev/null 2>&1 \
    || fail "cannot read secrets on $REPO — the token needs the 'repo' scope
       and you need admin on the repository"
}

# The release script greps `security find-identity` for an exact identity name,
# so a certificate for a different name signs nothing. Read the expected name
# out of the script rather than repeating it here.
expected_identity() {
  # shellcheck disable=SC2016 # ${SIGNING_IDENTITY:-...} is the text being matched
  sed -n 's/^readonly SIGNING_IDENTITY="${SIGNING_IDENTITY:-\(.*\)}"$/\1/p' \
    "$(dirname "${BASH_SOURCE[0]}")/../release_macos.sh"
}

# Proves the password is right and shows whose certificate it is, which are the
# two things that would otherwise fail inside a CI job ten minutes from now.
inspect_certificate() {
  local p12="$1" password="$2" subject=''
  for extra in '' '-legacy'; do
    # shellcheck disable=SC2086 # $extra is one optional flag, deliberately split
    if subject="$(openssl pkcs12 -in "$p12" -passin "pass:$password" \
        -nokeys -clcerts $extra 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null)"; then
      [[ -n "$subject" ]] && break
    fi
  done

  if [[ -z "$subject" ]]; then
    fail 'could not read that .p12 with that password.
       Either the password is wrong, or it is not a PKCS#12 file. Export it from
       Keychain Access: right-click the "Developer ID Application" identity ->
       Export, and keep the private key with it.'
  fi

  local name
  name="$(sed -n 's/.*CN *= *\([^,]*\).*/\1/p' <<<"$subject")"
  note "certificate: ${name:-$subject}"

  local expected
  expected="$(expected_identity)"
  if [[ -n "$expected" && -n "$name" && "$name" != "$expected" ]]; then
    printf '\033[33m  warning:\033[0m tool/release_macos.sh signs as\n'
    printf '    %s\n  but this certificate is\n    %s\n' "$expected" "$name"
    printf '  CI will fail its preflight unless one of them changes.\n'
  fi
}

main() {
  preflight

  step 'The Developer ID certificate'
  local p12 cert_password
  ask_file '  path to the exported .p12: '
  p12="$ANSWER"
  read -r -s -p '  its export password: ' cert_password \
    || fail 'no more input; nothing was changed'
  printf '\n'
  [[ -n "$cert_password" ]] || fail 'an empty export password would upload an unencrypted private key'
  inspect_certificate "$p12" "$cert_password"

  step 'The App Store Connect API key'
  local p8 key_id issuer_id suggested
  ask_file '  path to AuthKey_XXXXXXXXXX.p8: '
  p8="$ANSWER"

  # The key id is in the filename Apple gives you, so offer it rather than
  # making someone read it off a web page they have already closed.
  suggested="$(basename "$p8" | sed -n 's/^AuthKey_\([A-Z0-9]\{10\}\)\.p8$/\1/p')"
  if [[ -n "$suggested" ]]; then
    ask "  key id [$suggested]: "
    key_id="${ANSWER:-$suggested}"
  else
    ask '  key id: '
    key_id="$ANSWER"
  fi
  [[ "$key_id" =~ ^[A-Z0-9]{8,12}$ ]] || fail "'$key_id' does not look like a key id"

  ask '  issuer id (a UUID from App Store Connect): '
  issuer_id="$ANSWER"
  [[ "$issuer_id" =~ ^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$ ]] \
    || fail "'$issuer_id' is not a UUID"

  step "Setting five secrets on $REPO"
  printf '  these will be replaced if they already exist.\n'
  ask '  continue? [y/N] '
  local confirm="$ANSWER"
  [[ "$confirm" == [yY]* ]] || fail 'nothing was changed'

  # -A keeps it on one line, so the decode on the runner has nothing to trip on.
  openssl base64 -A -in "$p12" \
    | gh secret set MACOS_CERTIFICATE_P12 --repo "$REPO" >/dev/null
  note 'MACOS_CERTIFICATE_P12'

  printf '%s' "$cert_password" \
    | gh secret set MACOS_CERTIFICATE_PASSWORD --repo "$REPO" >/dev/null
  note 'MACOS_CERTIFICATE_PASSWORD'

  # Piped as-is rather than through a variable: a PEM key's trailing newline is
  # part of the file, and notarytool is entitled to care.
  gh secret set APPLE_API_KEY_P8 --repo "$REPO" <"$p8" >/dev/null
  note 'APPLE_API_KEY_P8'

  printf '%s' "$key_id" | gh secret set APPLE_API_KEY_ID --repo "$REPO" >/dev/null
  note 'APPLE_API_KEY_ID'

  printf '%s' "$issuer_id" \
    | gh secret set APPLE_API_ISSUER_ID --repo "$REPO" >/dev/null
  note 'APPLE_API_ISSUER_ID'

  step 'Secrets now on the repository'
  gh secret list --repo "$REPO"

  printf '\n\033[1mDone.\033[0m Tag a version to use them: git tag v%s && git push origin v%s\n' \
    "$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)" \
    "$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)"
}

main "$@"
