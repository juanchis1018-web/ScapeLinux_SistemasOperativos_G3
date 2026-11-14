#!/usr/bin/env bash
# Nivel 6 - La fuga final (tareas programadas: cron)
# Se completa con "verificar --final" cuando cron ya ejecutó /opt/scapelinux/bin/fuga.
set -euo pipefail
. "$(dirname "$0")/comun.sh"
DIR="$HOME_J/nivel6"
FUGA="/opt/scapelinux/bin/fuga"

preparar() {
    leer_llave
    limpiar
    carpeta_nueva "$DIR"
}

limpiar() {
    crontab -r -u "$JUGADOR" 2>/dev/null || true
    como_jugador rm -rf "$DIR"
}

# $1: momento en que empezó el nivel, en segundos desde 1970.
comprobar() {
    desde="${1:?Falta el inicio del nivel}"
    tareas="$(crontab -l -u "$JUGADOR" 2>/dev/null || true)"
    grep -Fq "$FUGA" <<< "$tareas" || fallar "No hay ninguna tarea cron que ejecute $FUGA."
    como_jugador test -s "$DIR/fuga.log" || fallar "La tarea todavía no se ha ejecutado. Espera al minuto programado."
    if command -v journalctl >/dev/null 2>&1; then
        registro="$(journalctl -u cron --since "@$desde" -o cat --no-pager 2>/dev/null || true)"
        grep -Eq "\($JUGADOR\) CMD \(.*$FUGA" <<< "$registro" \
            || fallar "El registro de cron no muestra la ejecución: la fuga la debe hacer cron, no tú."
    fi
}

despachar "$@"
