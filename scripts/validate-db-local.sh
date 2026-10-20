#!/usr/bin/env bash
set -euo pipefail
printf '== Nodo Sur E3: MariaDB Docker en VM279 ==\n'
systemctl is-active nodosur-db-prod.service
systemctl is-enabled nodosur-db-prod.service
sudo /usr/local/sbin/nodosur-db-check-e3
