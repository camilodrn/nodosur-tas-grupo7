#!/usr/bin/env bash
set -euo pipefail
base=https://nodosur07.tas
args=(--silent --show-error --connect-timeout 5 --max-time 20)
if [[ -n ${NODOSUR_CA_CERT:-} ]]; then
  args+=(--cacert "$NODOSUR_CA_CERT")
elif [[ ${NODOSUR_INSECURE:-0} == 1 ]]; then
  args+=(--insecure)
  echo 'AVISO: diagnóstico sin validación de confianza TLS' >&2
fi
failed=0
for path in / /tienda/ /carrito/ /mi-cuenta/; do
  if code=$(curl "${args[@]}" -o /dev/null -w '%{http_code}' "$base$path"); then
    printf '%-20s HTTP %s\n' "$path" "$code"
    [[ $code == 200 ]] || failed=1
  else
    echo "ERROR: conexión $path" >&2
    failed=1
  fi
done
if headers=$(curl "${args[@]}" --head http://nodosur07.tas/); then
  if ! printf '%s\n' "$headers" | tr -d '\r' | grep -Eiq '^location: https://nodosur07\.tas/$'; then
    echo 'ERROR: falta redirección al HTTPS canónico' >&2
    failed=1
  fi
  if ! printf '%s\n' "$headers" | grep -Eq '^HTTP/[^ ]+ (301|302|307|308) '; then
    failed=1
  fi
else
  failed=1
fi
exit "$failed"
