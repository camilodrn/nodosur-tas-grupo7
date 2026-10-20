#!/usr/bin/env bash
set -euo pipefail

IP="10.33.195.194"
IFACE="ens18"

iptables -S DOCKER-USER >/dev/null
iptables -S FORWARD | grep -F -- '-j DOCKER-USER' >/dev/null

for PORT in 80 443; do
  MATCH=(
    -i "$IFACE"
    -p tcp
    -m conntrack
    --ctdir ORIGINAL
    --ctorigdst "$IP"
    --ctorigdstport "$PORT"
  )

  # Bloqueo por defecto para cada puerto.
  if ! iptables -C DOCKER-USER \
    "${MATCH[@]}" -j DROP 2>/dev/null; then
    iptables -I DOCKER-USER 1 \
      "${MATCH[@]}" -j DROP
  fi

  # Redes autorizadas.
  for SOURCE in \
    10.30.248.0/24 \
    10.33.21.0/24
  do
    if ! iptables -C DOCKER-USER \
      "${MATCH[@]}" -s "$SOURCE" \
      -j RETURN 2>/dev/null; then
      iptables -I DOCKER-USER 1 \
        "${MATCH[@]}" -s "$SOURCE" \
        -j RETURN
    fi
  done
done
