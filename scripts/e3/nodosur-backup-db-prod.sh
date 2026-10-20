#!/usr/bin/env bash
set -euo pipefail
umask 077

CONTAINER="nodosur-db-staging"
DIR="/var/backups/nodosur/daily"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT="$DIR/nodo_sur_final-$STAMP.sql.gz"

# Solo respaldar el contenedor de pruebas si está saludable.
STATUS="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER")"

if [[ "$STATUS" != "healthy" ]]; then
  echo "ERROR: MariaDB staging no está saludable."
  exit 1
fi

install -d -m 0700 "$DIR"

if [[ -e "$OUT" ]]; then
  echo "ERROR: ya existe un respaldo con este nombre."
  exit 1
fi

TMP="$(mktemp "$DIR/.nodosur-stage-XXXXXX")"
SUM_TMP="$(mktemp "$DIR/.nodosur-sha-XXXXXX")"

trap 'rm -f "$TMP" "$SUM_TMP"' EXIT

# Extraer SQL desde MariaDB Docker; nunca desde el host.
docker exec "$CONTAINER" sh -ec '
  umask 077
  cfg=$(mktemp /tmp/nodosur-client.XXXXXX)
  trap "rm -f \"$cfg\"" EXIT

  printf "[client]\nuser=root\npassword=%s\n" \
    "$(cat /run/secrets/root_password)" > "$cfg"

  mariadb-dump \
    --defaults-extra-file="$cfg" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    --events \
    --default-character-set=utf8mb4 \
    nodo_sur_final
' | gzip -9 > "$TMP"

# Verificaciones antes de publicar el respaldo.
gzip -t "$TMP"

TABLES="$(
  gzip -cd "$TMP" |
    awk '/^CREATE TABLE / {n++} END {print n+0}'
)"

if [[ "$TABLES" != "52" ]]; then
  echo "ERROR: se esperaban 52 tablas; encontradas: $TABLES"
  exit 1
fi

# Publicar solamente el archivo ya verificado.
mv -- "$TMP" "$OUT"

(
  cd "$DIR"
  sha256sum "$(basename "$OUT")"
) > "$SUM_TMP"

mv -- "$SUM_TMP" "$OUT.sha256"

echo "RESPALDO DOCKER PRODUCCION: OK"
echo "Tablas: $TABLES"
echo "Archivo: $OUT"
du -h "$OUT"
