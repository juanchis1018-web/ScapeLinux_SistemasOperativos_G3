#!/usr/bin/env bash
# Nivel 2 - El archivo bloqueado (permisos y dueños: chown, chmod)
set -euo pipefail
. "$(dirname "$0")/comun.sh"
DIR="$SRV/nivel2"
PUERTA="$DIR/puerta.txt"

preparar() {
    leer_llave
    limpiar
    install -d -o root -g root -m 755 "$DIR"
    printf 'La puerta se abre.\nLLAVE: %s\n' "$LLAVE" > "$PUERTA"
    chown root:root "$PUERTA"
    chmod 000 "$PUERTA"
}

limpiar() { rm -rf "$DIR"; }

comprobar() {
    [[ -f "$PUERTA" && ! -L "$PUERTA" ]] || fallar "No existe $PUERTA. Usa verificar --reiniciar-nivel."
    [[ "$(stat -c %U "$PUERTA")" == "$JUGADOR" ]] || fallar "puerta.txt todavía no te pertenece."
    permisos="$(stat -c %A "$PUERTA")"
    [[ "${permisos:1:1}" == "r" ]] || fallar "puerta.txt todavía no tiene permiso de lectura para ti."
}

despachar "$@"
