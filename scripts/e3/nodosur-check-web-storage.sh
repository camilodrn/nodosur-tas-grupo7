#!/usr/bin/env bash
# Precondición de arranque: no escribir uploads en un directorio local vacío.
set -euo pipefail
case "${1:-}" in web1|web2) backend="$1" ;; *) exit 2 ;; esac
mount=/srv/nodosur/nfs/uploads
mountpoint -q "$mount"
fstype=$(findmnt -rn -M "$mount" -o FSTYPE)
source=$(findmnt -rn -M "$mount" -o SOURCE)
options=$(findmnt -rn -M "$mount" -o OPTIONS)
case "$fstype" in nfs|nfs4) ;; *) echo 'ERROR: uploads no es NFS' >&2; exit 1 ;; esac
case "$source" in 10.33.199.59:/*) ;; *) echo 'ERROR: servidor NFS inesperado' >&2; exit 1 ;; esac
case ",$options," in *,rw,*) ;; *) echo 'ERROR: uploads no es RW' >&2; exit 1 ;; esac
test -s "/srv/nodosur/$backend/html/wp-config.php"
test -s "/srv/nodosur/$backend/html/wp-includes/version.php"
echo "Precondiciones de $backend: NFS RW y archivos WordPress presentes"
