#!/usr/bin/env bash
# ENSAYO E3 en Fedora: persistencia WordPress y uploads durante REINICIO
# SOLO de los contenedores con etiqueta nodosur-e3-ensayo.
# No detiene ni reinicia FurgoPlus ni VMs USM. Escribe un marcador ficticio
# en el volumen compartido y lo elimina al terminar.
set -euo pipefail

raiz=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export NODOSUR_E3_LAB_SECRETS="$HOME/.local/share/nodosur-e3-ensayo"
c=(docker compose -p nodosur-e3-ensayo -f "$raiz/compose/e3-lab/compose.yaml")
nombre=nodosur-e3-ensayo

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ $(docker context show) == default ]] || fail "requiere contexto Docker default de Fedora"
"${c[@]}" config --quiet || fail 'Compose del ensayo inválido'

echo '=== AISLAMIENTO ANTES DEL REINICIO ==='
for servicio in database web1 web2 proxy; do
  cid=$("${c[@]}" ps -q "$servicio")
  [[ -n $cid ]] || fail "no existe contenedor $servicio"
  etiqueta=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$cid")
  [[ $etiqueta == "$nombre" ]] || fail "$servicio no pertenece al ensayo"
  echo "$servicio: proyecto $etiqueta"
done
dbid=$("${c[@]}" ps -q database)
dbvol=$(docker inspect "$dbid" -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}')
[[ $dbvol == nodosur-e3-ensayo_database_data ]] || fail 'volumen DB inesperado'
echo "BD: volumen $dbvol"

for servicio in web1 web2; do
  cid=$("${c[@]}" ps -q "$servicio")
  uploads=$(docker inspect "$cid" -f '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Name}}:{{.RW}}{{end}}{{end}}')
  [[ $uploads == nodosur-e3-ensayo_shared_uploads:true ]] || fail "$servicio: uploads inesperado"
done

wp_estado() {
  local servicio=$1
  "${c[@]}" exec -T -u www-data "$servicio" php -r '
    require "/var/www/html/wp-load.php";
    if (!is_blog_installed()) {
      fwrite(STDERR, "ERROR: WordPress no instalado\n");
      exit(10);
    }
    $nombre = get_option("blogname");
    if ($nombre !== "Nodo Sur - Ensayo E3") {
      fwrite(STDERR, "ERROR: título WordPress de ensayo inesperado\n");
      exit(11);
    }
    $usuarios = get_users(["role" => "administrator", "fields" => "ID"]);
    if (count($usuarios) < 1) {
      fwrite(STDERR, "ERROR: administrador de prueba ausente\n");
      exit(12);
    }
    echo "WORDPRESS_INSTALADO: titulo=" . $nombre . " admin_presente=si\n";
  ' </dev/null
}

echo '=== ESTADO WORDPRESS ANTES ==='
for servicio in web1 web2; do
  echo "$servicio: $(wp_estado "$servicio")"
done

ruta="/var/www/html/wp-content/uploads/.nodosur-e3-persistencia-$(date +%s)-$$.txt"
creado=0
limpiar() {
  local rc=$?
  trap - EXIT
  if (( creado )); then
    if "${c[@]}" exec -T -u www-data web1 rm -f -- "$ruta" </dev/null; then
      echo 'LIMPIEZA: MARCADOR TEMPORAL ELIMINADO'
    else
      echo "ATENCION: no se pudo eliminar el archivo ficticio $ruta" >&2
      rc=1
    fi
  fi
  exit "$rc"
}
trap limpiar EXIT

echo '=== ARCHIVO TEMPORAL ANTES ==='
creado=1
"${c[@]}" exec -T -u www-data web1 sh -ec \
  'printf "nodosur-e3-persistencia\n" > "$1"' sh "$ruta" </dev/null
pre=$("${c[@]}" exec -T -u www-data web2 sha256sum "$ruta" </dev/null | awk '{print $1}')
esperado=$(printf 'nodosur-e3-persistencia\n' | sha256sum | awk '{print $1}')
[[ $pre == "$esperado" ]] || fail 'hash inicial distinto'
echo "SHA256 antes: $pre"

echo '=== REINICIAR SOLO BASE DE DATOS FICTICIA ==='
"${c[@]}" restart database
salud=''
for i in $(seq 1 45); do
  salud=$(docker inspect "$dbid" -f '{{.State.Health.Status}}')
  [[ $salud == healthy ]] && break
  [[ $salud != unhealthy ]] || true
  sleep 2
done
[[ $salud == healthy ]] || fail "MariaDB no alcanzó healthy (estado $salud)"
echo 'MARIADB: HEALTHY TRAS REINICIO'

echo '=== REINICIAR SOLO WEB1 WEB2 Y PROXY DEL ENSAYO ==='
"${c[@]}" restart web1 web2 proxy

echo '=== ESPERAR RESPUESTA PUBLICA LOCAL ==='
publicado=0
for i in $(seq 1 45); do
  code=$(curl --noproxy '*' --silent --show-error --connect-timeout 2 --max-time 5 \
    -o /dev/null -w '%{http_code}' http://127.0.0.1:19090/ 2>/dev/null) || code=000
  if [[ $code == 200 ]]; then publicado=1; break; fi
  sleep 2
done
[[ $publicado == 1 ]] || fail "proxy sin HTTP 200 (último $code)"
echo 'PROXY: HTTP 200 TRAS REINICIO'

echo '=== ESTADO WORDPRESS DESPUES ==='
for servicio in web1 web2; do
  echo "$servicio: $(wp_estado "$servicio")"
done

echo '=== VERIFICAR PERSISTENCIA DEL ARCHIVO ==='
post1=$("${c[@]}" exec -T -u www-data web1 sha256sum "$ruta" </dev/null | awk '{print $1}')
post2=$("${c[@]}" exec -T -u www-data web2 sha256sum "$ruta" </dev/null | awk '{print $1}')
printf 'SHA256 web1 después: %s\nSHA256 web2 después: %s\n' "$post1" "$post2"
[[ $pre == "$post1" && $pre == "$post2" ]] || fail 'pérdida o alteración de uploads'
echo 'PERSISTENCIA DE DATOS Y UPLOADS: OK'

echo '=== ESPERAR A QUE AMBOS BACKENDS VUELVAN AL BALANCEO ==='
# La primera respuesta HTTP 200 solo prueba que AL MENOS UN backend funciona.
# Tras reiniciar puede haber eventos Layer4 DOWN y recuperacion Layer7 UP.
# Por eso esperamos un ciclo completo 200 que incluya ambos backends,
# sin reiniciar de nuevo ni asumir tiempos RTO/RPO.
listos=0
for intento in $(seq 1 45); do
  uno=0
  dos=0
  fallos=0
  for i in 1 2 3 4 5 6; do
    cab=$(curl --noproxy '*' --silent --show-error \
      --connect-timeout 3 --max-time 15 -D - -o /dev/null \
      http://127.0.0.1:19090/) || {
      fallos=$((fallos+1))
      continue
    }
    http=$(printf '%s\n' "$cab" | tr -d '\r' | awk 'NR==1 {print $2}')
    backend=$(printf '%s\n' "$cab" | tr -d '\r' | awk 'tolower($1)=="x-nodosur-lab-backend:" {print $2}')
    if [[ $http != 200 ]]; then
      fallos=$((fallos+1))
      continue
    fi
    case $backend in
      web1) uno=$((uno+1));;
      web2) dos=$((dos+1));;
      *) fallos=$((fallos+1));;
    esac
  done
  if (( fallos == 0 && uno > 0 && dos > 0 )); then
    listos=1
    break
  fi
  echo "Esperando salud de ambos: intento=$intento web1=$uno web2=$dos errores=$fallos"
  sleep 2
done
(( listos == 1 )) || fail 'ambos backends no volvieron al balanceo dentro de la ventana'
echo "BALANCEO DESPUES DE RECUPERACION: web1=$uno web2=$dos (6 solicitudes HTTP 200)"

echo '=== FURGOPLUS (OBSERVACION SOLAMENTE) ==='
docker ps -a --filter name=furgoplus --format '{{.Names}} {{.Status}}'

echo '=== ESTADO CONTENEDORES ENSAYO ==='
"${c[@]}" ps

echo 'RESULTADO: PERSISTENCIA DE WORDPRESS Y UPLOADS VALIDADA'
