#!/usr/bin/env bash
# E3: inspeccion de SOLO LECTURA para los cuatro roles Docker de Nodo Sur.
# Ejecutar en la VM correspondiente: bash scripts/preflight-e3.sh web1|web2|db|proxy
# No arranca/detiene/recrea contenedores, no cambia permisos, no imprime secretos.
set -euo pipefail

rol="${1:-}"
repo="${NODOSUR_REPO_DIR:-$HOME/nodosur-tas-grupo7}"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
check_file() {
    sudo test -s "$1" || fail "archivo requerido ausente/vacio: $1"
    ok "archivo requerido presente: $1 (contenido NO mostrado)"
}

case "$rol" in
    web1) compose="$repo/compose/web1/compose.yaml"; service=wordpress; nombre=nodosur-web1 ;;
    web2) compose="$repo/compose/web2/compose.yaml"; service=wordpress; nombre=nodosur-web2 ;;
    db) compose="$repo/compose/db-stage/compose.prod.yaml"; service=mariadb; nombre=nodosur-db-staging ;;
    proxy) compose="$repo/compose/proxy/compose.prod.yaml"; service=haproxy; nombre=nodosur-haproxy ;;
    *) fail 'uso: bash scripts/preflight-e3.sh web1|web2|db|proxy (en VM del rol)' ;;
esac

printf '=== PREFLIGHT E3 (SOLO LECTURA): %s ===\n' "$rol"
test -f "$compose" || fail "Compose no encontrado: $compose"
sudo docker compose -f "$compose" config --quiet || fail 'Compose invalido'
ok 'docker compose config --quiet'

estado=$(sudo docker inspect --type container --format '{{.State.Status}}' "$nombre") || fail 'contenedor no existe'
imagen=$(sudo docker inspect --type container --format '{{.Config.Image}}' "$nombre") || fail 'imagen no disponible'
printf 'Contenedor: %s | estado=%s | imagen=%s\n' "$nombre" "$estado" "$imagen"
[[ "$estado" == running ]] || fail 'el contenedor no esta running'
ok 'contenedor ejecutandose'

if [[ "$rol" == web1 || "$rol" == web2 ]]; then
    [[ "$imagen" == 'wordpress:7.1.2-php8.3-apache' ]] || fail 'imagen WordPress distinta a la inventariada'
    sudo test -d "/srv/nodosur/$rol/html" || fail 'falta HTML bind-mounted'
    findmnt -M /srv/nodosur/nfs/uploads >/dev/null || fail 'uploads NFS no esta montado'
    ok 'directorio HTML y mount de uploads existentes'

    check_file /etc/nodosur/apache/nodosur-uploads.conf
    montaje=$(sudo docker inspect --type container --format '{{range .Mounts}}{{if eq .Destination "/etc/apache2/conf-enabled/nodosur-uploads.conf"}}{{.Source}}|{{.RW}}{{end}}{{end}}' "$nombre")
    [[ "$montaje" == '/etc/nodosur/apache/nodosur-uploads.conf|false' ]] || fail 'hardening Apache no montado en solo lectura'
    uploads=$(sudo docker inspect --type container --format '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Source}}|{{.RW}}{{end}}{{end}}' "$nombre")
    [[ "$uploads" == '/srv/nodosur/nfs/uploads|true' ]] || fail 'uploads no corresponde a bind RW esperado'
    ok 'mounts de Apache readonly y uploads NFS RW'

    sudo docker exec "$nombre" apache2ctl -t || fail 'sintaxis Apache invalida'
    ok 'apache2ctl -t'
    [[ "$rol" != web2 ]] || check_file /etc/nodosur/secrets/cms_web62.password
fi

if [[ "$rol" == db ]]; then
    [[ "$imagen" == 'mariadb:10.11' ]] || fail 'imagen MariaDB distinta a la inventariada'
    check_file /etc/nodosur/secrets/db-stage-root.password
    volumen=$(sudo docker inspect --type container --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}' "$nombre")
    [[ "$volumen" == nodosur-db-staging_db_stage_data ]] || fail 'VOLUMEN DB DISTINTO: NO RECREAR NI CAMBIAR'
    salud=$(sudo docker inspect --type container --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}' "$nombre")
    printf 'Volumen DB=%s | health=%s\n' "$volumen" "$salud"
    [[ "$salud" == healthy ]] || fail 'healthcheck MariaDB no healthy'
    ok 'BD saludable en volumen historico'
fi

if [[ "$rol" == proxy ]]; then
    [[ "$imagen" == 'haproxy:3.2.23-alpine' ]] || fail 'imagen HAProxy distinta a la inventariada'
    check_file /etc/nodosur/tls/haproxy-www.pem
    sudo docker exec "$nombre" haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg || fail 'config HAProxy invalida'
    ok 'haproxy -c'
fi

echo 'RESULTADO: PREFLIGHT E3 OK (comprobaciones acotadas y sin escrituras)'
echo 'ALCANCE: no certifica estado de otras VMs, seguridad integral, reproduccion desde cero ni flujo de compra.'
