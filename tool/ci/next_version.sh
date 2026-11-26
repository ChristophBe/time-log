#!/usr/bin/env bash
# Prints the next semantic version (no leading v), decided from the commit messages
# since the latest v* tag: `type!:` or a BREAKING CHANGE footer -> major, `feat` ->
# minor, anything else -> patch. With no tag yet the first release is 0.1.0.
set -euo pipefail

last="$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || true)"
if [[ -z "$last" ]]; then
  echo '0.1.0'
  exit 0
fi

IFS=. read -r major minor patch <<<"${last#v}"
bump=patch
while IFS= read -r -d '' msg; do
  msg="${msg#"${msg%%[![:space:]]*}"}" # %B leaves a newline ahead of each later record
  subject="${msg%%$'\n'*}"
  if [[ "$subject" =~ ^[a-zA-Z]+(\([^\)]*\))?!: ]] || grep -qE '^BREAKING[ -]CHANGE' <<<"$msg"; then
    bump=major
    break
  elif [[ "$subject" =~ ^feat(\([^\)]*\))?: ]]; then
    bump=minor
  fi
done < <(git log "$last..HEAD" --format='%B%x00')

case "$bump" in
  major) echo "$((major + 1)).0.0" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  *) echo "$major.$minor.$((patch + 1))" ;;
esac
