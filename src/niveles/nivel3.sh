#!/usr/bin/env bash
# Nivel 3 - El proceso bloqueador (procesos y señales: ps, kill)
set -euo pipefail
. "$(dirname "$0")/comun.sh"
DIR="$HOME_J/nivel3"
LLAVE_GUARDADA="$DATOS/nivel3.llave"
SERVICIO="scapelinux-puerta.service"

preparar() {
    leer_llave
    limpiar
    carpeta_nueva "$DIR"
    install -m 600 /dev/null "$LLAVE_GUARDADA"
    printf '%s\n' "$LLAVE" > "$LLAVE_GUARDADA"
    systemctl start "$SERVICIO"
}

limpiar() {
    # Se borra la llave antes de detener el servicio, para que abrir_puerta no la entregue.
    rm -f "$LLAVE_GUARDADA"
    systemctl stop "$SERVICIO" 2>/dev/null || true
    como_jugador rm -rf "$DIR"
}

comprobar() {
    if systemctl is-active --quiet "$SERVICIO"; then
        fallar "El proceso puerta_bloqueada sigue activo."
    fi
}

despachar "$@"
