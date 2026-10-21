#!/usr/bin/env bash
# Huella semantica de Compose para comparar el repo local con cada VM.
# Solo consulta "docker compose config --format json", sin desplegar y sin
# imprimir contenido de secretos. Ejecutar donde Docker Compose este instalado.
# Ej.: NODOSUR_REPO_DIR="$PWD" bash scripts/compose-fingerprint-e3.sh web1
set -euo pipefail

rol="${1:-}"
repo="${NODOSUR_REPO_DIR:-$HOME/nodosur-tas-grupo7}"
case "$rol" in
  web1) archivo=compose/web1/compose.yaml ;;
  web2) archivo=compose/web2/compose.yaml ;;
  db) archivo=compose/db-stage/compose.prod.yaml ;;
  proxy) archivo=compose/proxy/compose.prod.yaml ;;
  *) echo 'Uso: compose-fingerprint-e3.sh web1|web2|db|proxy' >&2; exit 2 ;;
esac

test -f "$repo/$archivo" || { echo "Falta archivo $repo/$archivo" >&2; exit 1; }

# La orden 'compose config' es local: no depende de que el daemon este activo.
if docker compose version >/dev/null 2>&1; then
  cmd=(docker)
elif sudo docker compose version >/dev/null 2>&1; then
  cmd=(sudo docker)
else
  echo 'ERROR: Docker Compose no esta disponible' >&2
  exit 1
fi

# No se muestra el JSON completo: solo una huella de su representación
# normalizada. Los secretos de Compose se referencian por archivo privado.
# Los comentarios/espacios del YAML no afectan la comparación.
"${cmd[@]}" compose -f "$repo/$archivo" config --format json |
  python3 -c '
import json, hashlib, sys
data = json.load(sys.stdin)
normalized = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
print("HUELLA_COMPOSE_E3=" + hashlib.sha256(normalized.encode("utf-8")).hexdigest())
'
