#!/usr/bin/env bash
# Inicializacion CONTROLADA de WordPress SOLO en el ensayo Docker Fedora.
# Escribe únicamente en el DB y los volúmenes del proyecto nodosur-e3-ensayo.
# No toca WooCommerce/NFS/VLAN/TLS productivos ni FurgoPlus.
set -euo pipefail

[[ ${1:-} == --permitir-instalacion ]] || {
  echo "Uso: bash scripts/install-e3-lab-wordpress.sh --permitir-instalacion" >&2
  exit 2
}

raiz=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
dir="$HOME/.local/share/nodosur-e3-ensayo"
export NODOSUR_E3_LAB_SECRETS="$dir"
c=(docker compose -p nodosur-e3-ensayo -f "$raiz/compose/e3-lab/compose.yaml")
archivo="$dir/wp_admin_password"

[[ $(docker context show) == default ]] || {
  echo "ERROR: Docker context debe ser default de Fedora" >&2
  exit 1
}
[[ $(stat -c %a "$dir") == 700 ]] || {
  echo "ERROR: directorio privado del ensayo debe ser modo 700" >&2
  exit 1
}
[[ ! -e "$archivo" ]] || {
  echo "ERROR: contraseña de WordPress ya existe; no reinstalar" >&2
  exit 1
}
"${c[@]}" config --quiet

for servicio in database web1 web2 proxy; do
  cid=$("${c[@]}" ps -q "$servicio")
  [[ -n $cid ]] || { echo "ERROR: $servicio no esta creado" >&2; exit 1; }
  etiqueta=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$cid")
  [[ $etiqueta == nodosur-e3-ensayo ]] || { echo "ERROR: proyecto invalido en $servicio" >&2; exit 1; }
done

for servicio in web1 web2; do
  "${c[@]}" exec -T -u www-data "$servicio" \
    test -w /var/www/html/wp-content/uploads </dev/null || {
    echo "ERROR: uploads no escribible en $servicio" >&2
    exit 1
  }
done

echo '=== PREPARAR CLAVE DE ADMINISTRACION FICTICIA (NO MOSTRADA) ==='
umask 077
openssl rand -hex 32 > "$archivo"
chmod 0600 "$archivo"
[[ -s "$archivo" ]] || { echo "ERROR: contraseña ficticia vacia" >&2; exit 1; }

echo '=== INSTALAR WORDPRESS SOLO EN WEB1 DEL ENSAYO ==='
# WP_INSTALLING suprime el redirect al instalador durante bootstrap CLI.
# wp_install crea tablas y usuario admin ficticio en la MariaDB de ensayo.
# La contraseña va por STDIN: no se muestra en argumentos, logs ni Git.
if "${c[@]}" exec -T -u www-data web1 php -r '
  define("WP_INSTALLING", true);
  require "/var/www/html/wp-load.php";

  if (is_blog_installed()) {
      fwrite(STDERR, "ERROR: WordPress ya estaba instalado; no repetir\n");
      exit(4);
  }

  require_once ABSPATH . "wp-admin/includes/upgrade.php";

  $password = trim(stream_get_contents(STDIN));
  if (strlen($password) < 40) {
      fwrite(STDERR, "ERROR: contraseña de ensayo demasiado corta\n");
      exit(5);
  }

  $result = wp_install(
      "Nodo Sur - Ensayo E3",
      "nodosur_lab_admin",
      "administrador@nodosur.invalid",
      false,
      "",
      $password,
      ""
  );
  unset($password);

  if (empty($result["user_id"]) || !is_blog_installed()) {
      fwrite(STDERR, "ERROR: instalación incompleta; revisar sin reintentar a ciegas\n");
      exit(6);
  }

  echo "WORDPRESS_LAB_INSTALL_OK\n";
' < "$archivo"; then
  echo 'RESULTADO: WORDPRESS INSTALADO EN BASE DE DATOS FICTICIA'
  echo "Usuario de prueba: nodosur_lab_admin"
  echo "Contraseña guardada localmente (NO mostrada): $archivo"
  echo 'Siguiente paso: verificar homepage desde ambos backends y persistencia.'
else
  codigo=$?
  echo "ERROR: instalacion devolvio codigo $codigo; revisar estado ANTES de reintentar" >&2
  echo "La clave ficticia permanece en $archivo (no publicar)" >&2
  exit "$codigo"
fi
