#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/nodosur/nodosur-firewall-common.sh
apply_nodosur_rules NODOSUR_PROXY 10.33.195.194 '80 443' 10.30.248.0/24 10.33.21.0/24
