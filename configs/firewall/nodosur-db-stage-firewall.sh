#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/nodosur/nodosur-firewall-common.sh
apply_nodosur_rules NODOSUR_DB_LAB 10.33.199.60 13307 10.33.199.58 10.33.199.62
