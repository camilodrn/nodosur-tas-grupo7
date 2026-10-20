#!/usr/bin/env bash
set -euo pipefail

IP="10.33.199.60"
PORT="3306"
IFACE="ens19"

iptables -S DOCKER-USER >/dev/null
iptables -S FORWARD | grep -Fq -- '-j DOCKER-USER'

MATCH=(
  -i "$IFACE"
  -p tcp
  -m conntrack
  --ctdir ORIGINAL
  --ctorigdst "$IP"
  --ctorigdstport "$PORT"
)

# Bloquear conexiones no autorizadas.
if ! iptables -C DOCKER-USER \
  "${MATCH[@]}" -j DROP 2>/dev/null; then
  iptables -I DOCKER-USER 1 "${MATCH[@]}" -j DROP
fi

# Conservar los orígenes autorizados actualmente por UFW.
for SOURCE in \
  10.33.199.58 \
  10.33.199.62 \
  10.33.199.59
do
  if ! iptables -C DOCKER-USER \
    "${MATCH[@]}" -s "$SOURCE" -j RETURN 2>/dev/null; then
    iptables -I DOCKER-USER 1 \
      "${MATCH[@]}" -s "$SOURCE" -j RETURN
  fi
done
