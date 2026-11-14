#!/usr/bin/env bash
# ScapeLinux: prueba integral. Resuelve los seis niveles como lo haría el jugador
# y comprueba los controles de seguridad. Tarda unos 2 minutos por la espera de cron.
# Uso, en la VM Servidor y después de instalar: sudo bash prueba_integral.sh
# Al final deja una partida terminada; usa verificar --nueva-partida para jugar.
set -uo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecuta: sudo bash prueba_integral.sh"; exit 1; }
[[ -f /etc/scapelinux/instalado ]] || { echo "Primero instala ScapeLinux."; exit 1; }

SALIDA="$(dirname "$(readlink -f "$0")")/resultado_prueba_$(date +%Y%m%d_%H%M).txt"
exec > >(tee "$SALIDA") 2>&1
J() { runuser -u jugador -- "$@"; }
G() { runuser -u guardia -- "$@"; }
llave_de() { grep -oE '[0-9A-F]{4}-[0-9A-F]{4}' | head -1; }
ok=0; mal=0
prueba() {  # prueba "ID descripción" comando...
    local nombre="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "[OK]    $nombre"; ok=$((ok+1)); else echo "[FALLA] $nombre"; mal=$((mal+1)); fi
}
no() { ! "$@"; }

echo "ScapeLinux - prueba integral - $(date '+%Y-%m-%d %H:%M:%S')"
echo "Equipo: $(hostname) · $(. /etc/os-release; echo "$PRETTY_NAME") · $(uname -r)"
echo
J verificar --nueva-partida >/dev/null
prueba "P3  Base de datos con 6 niveles" test "$(python3 -I -c 'import sqlite3;print(sqlite3.connect("/var/lib/scapelinux/scapelinux.db").execute("select count(*) from nivel").fetchone()[0])')" = 6
prueba "P8  jugador no puede leer la base de datos" no J cat /var/lib/scapelinux/scapelinux.db
prueba "P9  sudo no permite chown sobre otro archivo" no J sudo -n chown jugador /etc/passwd
prueba "P9  sudo no permite chown hacia otro usuario" no J sudo -n chown guardia /srv/scapelinux/nivel2/puerta.txt

# Nivel 1
k=$(J find /home/jugador/nivel1 -type f -name '.*' -exec cat {} + | llave_de)
prueba "P6  Llave con formato inválido rechazada" no J verificar "1;DROP TABLE"
prueba "P6  Llave incorrecta rechazada" no J verificar 0000-0000
prueba "P5  Nivel 1: llave encontrada con find" test -n "$k"
prueba "P5  Nivel 1 superado" J verificar "$k"

# Nivel 2
prueba "P5  Nivel 2: puerta.txt no se puede leer al inicio" no J cat /srv/scapelinux/nivel2/puerta.txt
J sudo -n chown jugador /srv/scapelinux/nivel2/puerta.txt; J chmod u+r /srv/scapelinux/nivel2/puerta.txt
k=$(J cat /srv/scapelinux/nivel2/puerta.txt | llave_de)
prueba "P5  Nivel 2 superado con chown y chmod" J verificar "$k"

# Nivel 3
pid=$(pgrep -u jugador -f puerta_bloqueada | head -1)
prueba "P5  Nivel 3: proceso visible con ps" test -n "$pid"
J kill "$pid"; sleep 2
k=$(J cat /home/jugador/nivel3/llave.txt | llave_de)
prueba "P5  Nivel 3: llave entregada al detener el proceso" test -n "$k"
prueba "P5  Nivel 3 superado" J verificar "$k"

# Nivel 4
clave=$(J cat /home/jugador/nivel4/nota_del_guardia.txt | grep -oE 'guardia-[0-9a-f]+')
prueba "P5  Nivel 4: jugador no puede abrir la bóveda" no J cat /srv/scapelinux/boveda/llave.txt
prueba "P5  Nivel 4: guardia pertenece al grupo boveda" bash -c "id -nG guardia | grep -qw boveda"
prueba "P5  Nivel 4: la contraseña de la nota es válida" test -n "$clave"
k=$(G cat /srv/scapelinux/boveda/llave.txt | llave_de)
prueba "P5  Nivel 4 superado" J verificar "$k"

# Nivel 5
k=$(G grep ACTIVA /var/log/scapelinux/accesos.log | llave_de)
prueba "P5  Nivel 5: jugador no puede leer el log" no J cat /var/log/scapelinux/accesos.log
prueba "P5  Nivel 5 superado con grep" J verificar "$k"

# Nivel 6
J /opt/scapelinux/bin/fuga
echo "* * * * * /opt/scapelinux/bin/fuga" | J crontab -
prueba "P7  Nivel 6: ejecutar la fuga a mano no basta" no J verificar --final
echo "        Esperando a que cron ejecute la fuga (hasta 2 minutos)..."
for i in $(seq 1 24); do sleep 5; J verificar --final > /tmp/scapelinux_final.txt 2>&1 && break; done
prueba "P5  Nivel 6 superado por cron" grep -q "ESCAPASTE" /tmp/scapelinux_final.txt
cat /tmp/scapelinux_final.txt | sed 's/^/        /'
J crontab -r 2>/dev/null; rm -f /tmp/scapelinux_final.txt

echo
echo "Resultado: $ok correctas, $mal fallidas"
echo "Guardado en: $SALIDA"
[[ $mal -eq 0 ]]
