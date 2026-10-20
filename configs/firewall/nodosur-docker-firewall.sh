#!/bin/sh
set -eu

IP="$1"
PORT="$2"
PROXY="10.33.199.61"

# Confirmar que Docker preparo su cadena.
iptables -S FORWARD | grep -Fq -- '-j DOCKER-USER'

# Evitar duplicar la regla si ya existe.
if ! iptables -C DOCKER-USER \
  -p tcp -m conntrack --ctdir ORIGINAL \
  --ctorigdst "$IP" --ctorigdstport "$PORT" \
  ! -s "$PROXY" -j DROP 2>/dev/null
then
  iptables -I DOCKER-USER 1 \
    -p tcp -m conntrack --ctdir ORIGINAL \
    --ctorigdst "$IP" --ctorigdstport "$PORT" \
    ! -s "$PROXY" -j DROP
fi
