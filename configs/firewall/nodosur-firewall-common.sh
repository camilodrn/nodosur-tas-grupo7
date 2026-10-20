#!/usr/bin/env bash
# Biblioteca instalada root:root 0644 en /usr/local/lib/nodosur/.
# Reemplaza únicamente la cadena de este rol, en una transacción del filtro.
apply_nodosur_rules() {
  local chain="$1" ip="$2" ports="$3"
  shift 3
  local port source
  local -a match
  iptables -w 5 -S DOCKER-USER >/dev/null
  iptables -w 5 -C FORWARD -j DOCKER-USER
  {
    # Con --noflush, declarar esta cadena crea/reemplaza solo su contenido.
    printf '*filter\n:%s - [0:0]\n' "$chain"
    for source in "$@"; do
      printf -- '-A %s -s %s -j RETURN\n' "$chain" "$source"
    done
    printf -- '-A %s -j DROP\n' "$chain"
    for port in $ports; do
      match=(-p tcp -m conntrack --ctdir ORIGINAL --ctorigdst "$ip" --ctorigdstport "$port" -g "$chain")
      if iptables -w 5 -C DOCKER-USER "${match[@]}" 2>/dev/null; then
        printf -- '-D DOCKER-USER %s\n' "${match[*]}"
      fi
      printf -- '-I DOCKER-USER 1 %s\n' "${match[*]}"
    done
    printf 'COMMIT\n'
  } | iptables-restore --wait 5 --noflush
  # GOTO + RETURN devuelve lo permitido a FORWARD y a las reglas Docker.
  # El filtro cubre cualquier interfaz de ingreso, después del DNAT.
}
