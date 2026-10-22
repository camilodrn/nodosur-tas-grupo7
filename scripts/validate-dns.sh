#!/usr/bin/env bash
set -euo pipefail
server=10.33.195.205
failed=0
for transport in +notcp +tcp; do
  while read -r name expected; do
    if result=$(dig "@$server" "$name" A +short +time=3 +tries=1 "$transport"); then
      printf '%s %-25s %s\n' "$transport" "$name" "$result"
      if [[ "$result" != "$expected" ]]; then
        echo "ERROR: se esperaba $expected" >&2
        failed=1
      fi
    else
      failed=1
    fi
  done <<'RECORDS'
nodosur07.tas 10.33.195.194
www.nodosur07.tas 10.33.195.194
db.nodosur07.tas 10.33.199.60
ns1.nodosur07.tas 10.33.195.205
RECORDS
done
exit "$failed"
