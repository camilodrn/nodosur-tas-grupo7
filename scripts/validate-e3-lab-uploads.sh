#!/usr/bin/env bash
# Nodo Sur E3 — prueba reproducible del volumen compartido de laboratorio.
# Ejecutar SOLO en Fedora con Docker Engine "default".
# No detiene/recrea servicios ni toca VMs USM/FurgoPlus.
# Genera un archivo de texto ficticio y lo borra mediante trap.
set -euo pipefail

raiz=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export NODOSUR_E3_LAB_SECRETS="$HOME/.local/share/nodosur-e3-ensayo"
c=(docker compose -p nodosur-e3-ensayo -f "$raiz/compose/e3-lab/compose.yaml")
dest=/var/www/html/wp-content/uploads
vol=nodosur-e3-ensayo_shared_uploads

if [[ $(docker context show) != default ]]; then
  echo 'ERROR: se requiere contexto Docker default de Fedora' >&2
  exit 1
fi
"${c[@]}" config --quiet

echo '=== VOLUMEN DE LABORATORIO ==='
nombre=$(docker volume inspect "$vol" --format '{{.Name}}')
[[ $nombre == "$vol" ]] || { echo 'ERROR: volumen distinto' >&2; exit 1; }

for servicio in web1 web2; do
  cid=$("${c[@]}" ps -q "$servicio")
  [[ -n $cid ]] || { echo "ERROR: $servicio no existe" >&2; exit 1; }
  mnt=$(docker inspect "$cid" -f \
    '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Name}}:{{.RW}}{{end}}{{end}}')
  [[ $mnt == "$vol:true" ]] || {
    echo "ERROR: montaje inesperado $servicio: $mnt" >&2
    exit 1
  }
  echo "$servicio: montaje correcto"
  "${c[@]}" exec -T -u www-data "$servicio" sh -ec '
    stat -c "UPLOADS: UID=%u GID=%g MODO=%a" "$1"
    test -w "$1"
    echo "ESCRITURA: PERMITIDA"
  ' sh "$dest" </dev/null
done

archivo=".nodosur-e3-probe-$(date +%s)-$$.txt"
ruta="$dest/$archivo"
creado=0
limpiar() {
  local codigo=$?
  trap - EXIT
  if (( creado )); then
    if "${c[@]}" exec -T -u www-data web1 rm -f -- "$ruta" </dev/null; then
      echo 'LIMPIEZA: ARCHIVO FICTICIO ELIMINADO'
    else
      echo "ERROR: revisar archivo temporal $archivo, solo del ensayo" >&2
      codigo=1
    fi
  fi
  exit "$codigo"
}
trap limpiar EXIT

echo '=== ESCRIBIR WEB1 / LEER WEB2 ==='
creado=1
"${c[@]}" exec -T -u www-data web1 sh -ec \
  'printf "nodosur-ensayo-compartido\n" > "$1"' sh "$ruta" </dev/null

hash1=$("${c[@]}" exec -T -u www-data web1 sha256sum "$ruta" </dev/null | awk '{print $1}')
hash2=$("${c[@]}" exec -T -u www-data web2 sha256sum "$ruta" </dev/null | awk '{print $1}')
esperado=$(printf 'nodosur-ensayo-compartido\n' | sha256sum | awk '{print $1}')
printf 'SHA256 Web1: %s\nSHA256 Web2: %s\n' "$hash1" "$hash2"
[[ $hash1 == "$hash2" && $hash1 == "$esperado" ]] || {
  echo 'ERROR: los hashes no coinciden con el contenido de prueba' >&2
  exit 1
}
echo 'ALMACENAMIENTO COMPARTIDO: OK'

echo '=== ESTADO DE ENSAYO ==='
"${c[@]}" ps
echo 'RESULTADO: VALIDACION DEL VOLUMEN COMPLETADA'
