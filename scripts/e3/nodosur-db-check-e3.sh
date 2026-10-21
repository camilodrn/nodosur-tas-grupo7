#!/usr/bin/env bash
# Consulta fija. Instalar root:root 0755, sin directorios padres escribibles.
set -euo pipefail
[[ $# == 0 ]] || exit 2
systemctl is-active nodosur-db-prod.service
[[ $(docker inspect -f '{{.State.Health.Status}}' nodosur-db-staging) == healthy ]]
docker exec nodosur-db-staging healthcheck.sh --connect --innodb_initialized
# No imprime configuración del contenedor, variables ni credenciales.
port=$(docker port nodosur-db-staging 3306/tcp)
[[ "$port" == '10.33.199.60:3306' ]]
printf '%s\n' "$port"
