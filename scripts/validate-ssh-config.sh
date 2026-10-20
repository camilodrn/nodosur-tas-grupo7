#!/usr/bin/env bash
set -euo pipefail

printf '== Nodo Sur: validación SSH local ==\n'
printf '%s\n' 'Nota: la validación efectiva de sshd requiere tas_revision o la cuenta bootstrap/recovery de la VM.'

sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T | grep -E 'permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|allowgroups'

printf '\nGrupos de acceso y operación:\n'
getent group ssh-nodosur
getent group nodosur-ops
getent group systemd-journal

printf '\nGrupo sudo (debe contener recovery y tas_revision, no las cuentas operativas):\n'
getent group sudo
