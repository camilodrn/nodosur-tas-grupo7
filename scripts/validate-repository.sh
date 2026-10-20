#!/usr/bin/env bash
# Solo archivos locales: no inicia contenedores, consulta VMs ni cambia servicios.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for file in scripts/*.sh scripts/e3/*.sh configs/firewall/*.sh scripts/nodosur-db-check.example; do
  bash -n "$file"
done
echo 'PASS: sintaxis Bash'
python3 - <<'PY'
import ast
from pathlib import Path
for directory in ('scripts','tests','pruebas/e3'):
    for file in Path(directory).rglob('*.py'):
        ast.parse(file.read_text(), filename=str(file))
print('PASS: sintaxis Python')
PY
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  for file in compose/*/*.yaml; do
    docker compose -f "$file" config --quiet
  done
  echo 'PASS: seis Compose (cliente; sin daemon ni validación de imágenes)'
else
  echo 'SKIP: falta cliente Docker Compose'
fi
if command -v named-checkzone >/dev/null 2>&1; then
  named-checkzone nodosur07.tas configs/dns/db.nodosur07.tas.example
else
  echo 'SKIP: falta named-checkzone'
fi
if command -v visudo >/dev/null 2>&1; then
  for file in configs/sudo/*.example; do visudo -cf "$file"; done
else
  echo 'SKIP: falta visudo'
fi
if command -v php >/dev/null 2>&1; then
  for file in configs/wordpress/*.php; do php -l "$file"; done
else
  echo 'SKIP: falta PHP para lint de fragmentos'
fi
git diff --check
echo 'PASS: whitespace diff'
echo 'ALCANCE: no valida runtime HAProxy/Apache/BIND, systemd instalado ni red; ver auditoría.'
