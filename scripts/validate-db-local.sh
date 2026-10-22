#!/usr/bin/env bash
# Comprobacion de SOLO LECTURA para MariaDB productiva de E3 en VM279.
# Ejecutar con la cuenta autorizada, no como "sudo bash": usa sudo
# exclusivamente para consultas Docker (inspect y compose config).
set -euo pipefail

container='nodosur-db-staging'
volume='nodosur-db-staging_db_stage_data'
repo="${NODOSUR_REPO_DIR:-$HOME/nodosur-tas-grupo7}"
compose="$repo/compose/db-stage/compose.prod.yaml"

printf '== Nodo Sur E3: MariaDB Docker (VM279) ==\n'

if [[ ! -f "$compose" ]]; then
  echo "ERROR: falta Compose en $compose" >&2
  exit 1
fi

echo '=== Sintaxis del Compose productivo ==='
sudo docker compose -f "$compose" config --quiet
echo 'COMPOSE: VALIDO'

echo '=== Contenedor y datos activos ==='
if ! estado=$(sudo docker inspect --type container -f '{{.State.Status}}' "$container"); then
  echo "ERROR: no existe el contenedor $container" >&2
  exit 1
fi

salud=$(sudo docker inspect --type container -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}' "$container")
imagen=$(sudo docker inspect --type container -f '{{.Config.Image}}' "$container")
montaje=$(sudo docker inspect --type container -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}' "$container")

printf 'Contenedor: %s\nImagen: %s\nEstado: %s\nSalud: %s\nVolumen /var/lib/mysql: %s\n' \
  "$container" "$imagen" "$estado" "$salud" "$montaje"

if [[ "$estado" != 'running' ]]; then
  echo 'ERROR: MariaDB no esta ejecutandose' >&2
  exit 1
fi
if [[ "$salud" != 'healthy' ]]; then
  echo 'ERROR: el health check de MariaDB no indica healthy' >&2
  exit 1
fi
if [[ "$montaje" != "$volume" ]]; then
  echo 'ERROR: el volumen no coincide con el productivo esperado; no iniciar ni recrear contenedores' >&2
  exit 1
fi

echo 'RESULTADO: MARIA DB E3 OK (estado, salud y volumen)'
echo 'Alcance: no comprueba autenticacion de WordPress, tablas, datos ni restauracion.'
