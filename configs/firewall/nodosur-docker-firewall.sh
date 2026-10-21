#!/usr/bin/env bash
set -euo pipefail
case "${1:-}:${2:-}" in
  10.33.199.58:18081) chain=NODOSUR_WEB1 ;;
  10.33.199.62:18080) chain=NODOSUR_WEB2 ;;
  *) echo 'Uso: nodosur-docker-firewall.sh IP_BACKEND PUERTO' >&2; exit 2 ;;
esac
source /usr/local/lib/nodosur/nodosur-firewall-common.sh
apply_nodosur_rules "$chain" "$1" "$2" 10.33.199.61
