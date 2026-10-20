#!/usr/bin/env bash
set -euo pipefail
umask 077
case "${1:-}" in
  prod) container=nodosur-db-staging; dir=/var/backups/nodosur/daily; prefix=nodo_sur_final ;;
  staging) container=nodosur-db-lab; dir=/var/backups/nodosur/staging; prefix=nodo_sur_final-staging ;;
  *) echo 'Uso: nodosur-backup-db.sh prod|staging' >&2; exit 2 ;;
esac
install -d -m 0700 "$dir"
exec 9>"$dir/.backup.lock"
flock -n 9 || { echo 'ERROR: respaldo ya en curso' >&2; exit 1; }
[[ $(docker inspect -f '{{.State.Health.Status}}' "$container") == healthy ]] || {
  echo 'ERROR: MariaDB no está saludable' >&2; exit 1;
}
stamp=$(date -u +%Y%m%d-%H%M%S)
out="$dir/$prefix-$stamp.sql.gz"
[[ ! -e "$out" && ! -e "$out.sha256" ]] || { echo 'ERROR: nombre ya existente' >&2; exit 1; }
tmp=''; sum_tmp=''
trap 'rm -f -- "$tmp" "$sum_tmp"' EXIT
tmp=$(mktemp "$dir/.nodosur-dump-XXXXXX")
sum_tmp=$(mktemp "$dir/.nodosur-sha-XXXXXX")
docker exec "$container" sh -ec '
  umask 077
  cfg=$(mktemp /tmp/nodosur-client.XXXXXX)
  trap '\''rm -f "$cfg"'\'' EXIT
  # Escapar caracteres con significado en option files; secreto de una línea.
  test "$(awk '\''END {print NR}'\'' /run/secrets/root_password)" -eq 1
  password=$(sed '\''s/\\/\\\\/g; s/"/\\"/g'\'' /run/secrets/root_password)
  test -n "$password"
  printf "[client]\nuser=root\npassword=\"%s\"\n" "$password" > "$cfg"
  unset password
  mariadb-dump --defaults-extra-file="$cfg" --single-transaction --quick \
    --routines --triggers --events --hex-blob --default-character-set=utf8mb4 nodo_sur_final
' | gzip -9 > "$tmp"
gzip -t "$tmp"
tables=$(gzip -cd "$tmp" | awk '/^CREATE TABLE / {n++} END {print n+0}')
[[ "$tables" -gt 0 ]] || { echo 'ERROR: volcado sin tablas' >&2; exit 1; }
# 52 es la línea base de E3, no una restricción permanente del esquema.
if [[ "$tables" != 52 ]]; then
  echo "AVISO: $tables tablas; línea base de E3: 52. Revisar cambios de esquema." >&2
fi
digest=$(sha256sum "$tmp")
printf '%s  %s\n' "${digest%% *}" "${out##*/}" > "$sum_tmp"
mv -- "$tmp" "$out"
# El .sha256 se publica al final: el replicador debe exigir ambos archivos.
mv -- "$sum_tmp" "$out.sha256"
echo "RESPALDO $1: OK; tablas=$tables; archivo=$out"
