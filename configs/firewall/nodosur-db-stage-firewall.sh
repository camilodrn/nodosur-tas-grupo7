#!/usr/bin/env bash
set -euo pipefail

IP="10.33.199.60"
PORT="13307"
IFACE="ens19"

# Docker debe haber creado su cadena y el salto desde FORWARD.
iptables -S DOCKER-USER >/dev/null
iptables -S FORWARD | grep -F -- '-j DOCKER-USER' >/dev/null

MATCH=(
  -i "$IFACE"
  -p tcp
  -m conntrack
  --ctdir ORIGINAL
  --ctorigdst "$IP"
  --ctorigdstport "$PORT"
)

# Regla de bloqueo predeterminada para staging.
if ! iptables -C DOCKER-USER "${MATCH[@]}" -j DROP 2>/dev/null; then
  iptables -I DOCKER-USER 1 "${MATCH[@]}" -j DROP
fi

# Excepciones exclusivamente para los dos backends.
for SOURCE in 10.33.199.58 10.33.199.62; do
  if ! iptables -C DOCKER-USER \
    "${MATCH[@]}" -s "$SOURCE" -j RETURN 2>/dev/null; then
    iptables -I DOCKER-USER 1 \
      "${MATCH[@]}" -s "$SOURCE" -j RETURN
  fi
done
