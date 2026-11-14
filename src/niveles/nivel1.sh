#!/usr/bin/env bash
# Nivel 1 - La pista escondida (archivos ocultos: ls -a, find)
set -euo pipefail
. "$(dirname "$0")/comun.sh"
DIR="$HOME_J/nivel1"

preparar() {
    leer_llave
    carpeta_nueva "$DIR"
    salas=(sotano atico biblioteca cocina bodega)
    for sala in "${salas[@]}"; do
        como_jugador mkdir -p "$DIR/$sala/cajon"
        echo "Aquí no hay nada útil." | escribir_como_jugador "$DIR/$sala/nota.txt"
    done
    # Dos archivos ocultos falsos y uno verdadero, en salas al azar.
    for i in 1 2; do
        sala="${salas[$((RANDOM % 5))]}"
        echo "Sigue buscando..." | escribir_como_jugador "$DIR/$sala/.polvo$i"
    done
    sala="${salas[$((RANDOM % 5))]}"
    printf 'Encontraste la pista.\nLLAVE: %s\n' "$LLAVE" | escribir_como_jugador "$DIR/$sala/cajon/.$(aleatorio 3)"
}

limpiar() { como_jugador rm -rf "$DIR"; }

comprobar() { exit 0; }

despachar "$@"
