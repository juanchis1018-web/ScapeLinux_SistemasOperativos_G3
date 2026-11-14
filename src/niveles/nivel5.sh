#!/usr/bin/env bash
# Nivel 5 - El rastro en los logs (registros del sistema: grep)
# Requiere la contraseña de guardia del nivel 4, porque el log es del grupo boveda.
set -euo pipefail
. "$(dirname "$0")/comun.sh"
LOG="/var/log/scapelinux/accesos.log"

preparar() {
    leer_llave
    limpiar
    install -m 640 -o root -g boveda /dev/null "$LOG"
    awk -v llave="$LLAVE" -v pos="$(( (RANDOM * 32768 + RANDOM) % 3000 + 1 ))" 'BEGIN {
        srand()
        split("sotano atico biblioteca cocina bodega puerta-norte puerta-sur", sitio, " ")
        for (i = 1; i <= 3000; i++) {
            hora = sprintf("2026-11-%02d %02d:%02d:%02d", 1 + int(i / 300), int(rand()*24), int(rand()*60), int(rand()*60))
            lugar = sitio[1 + int(rand() * 7)]
            if (i == pos)
                print hora " " lugar " acceso concedido LLAVE=" llave " estado=ACTIVA"
            else if (i % 40 == 0)
                printf "%s %s acceso denegado LLAVE=%04X-%04X estado=REVOCADA\n", hora, lugar, int(rand()*65536), int(rand()*65536)
            else
                print hora " " lugar " movimiento detectado"
        }
    }' > "$LOG"
}

limpiar() { rm -f "$LOG"; }

comprobar() { exit 0; }

despachar "$@"
