#!/usr/bin/env bash
# Fail CI when local development secrets are accidentally tracked.
set -euo pipefail

blocked=0
while IFS= read -r path; do
  case "$path" in
    database/.yerel_*|.env|.env.local|server/.env|server/.env.local|android/key.properties|*.keystore|*.jks|*.p12)
      printf 'ERROR: tracked sensitive local file: %s\n' "$path" >&2
      blocked=1
      ;;
  esac
done < <(git ls-files)

if (( blocked )); then
  printf 'Remove these files from Git tracking, rotate exposed credentials and inspect history.\n' >&2
  exit 1
fi
printf 'No known local credentials tracked.\n'
