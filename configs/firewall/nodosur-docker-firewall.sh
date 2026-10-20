#!/bin/sh
set -eu

IP="$1"
PORT="$2"
PROXY="10.33.199.61"

iptables -S FORWARD | grep -Fq -- '-j DOCKER-USER'

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
