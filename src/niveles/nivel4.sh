#!/usr/bin/env bash
# Nivel 4 - La otra identidad (usuarios y grupos: su, groups)
set -euo pipefail
. "$(dirname "$0")/comun.sh"
DIR="$HOME_J/nivel4"
BOVEDA="$SRV/boveda"

preparar() {
    leer_llave
    limpiar
    clave="guardia-$(aleatorio 3)"
    echo "guardia:$clave" | chpasswd
    carpeta_nueva "$DIR"
    printf 'El guardia dejó caer esta nota:\n"Mi contraseña es %s. No se la digas a nadie."\n' "$clave" \
        | escribir_como_jugador "$DIR/nota_del_guardia.txt"
    install -d -o root -g boveda -m 750 "$BOVEDA"
    printf 'LLAVE: %s\n' "$LLAVE" > "$BOVEDA/llave.txt"
    chown root:boveda "$BOVEDA/llave.txt"
    chmod 640 "$BOVEDA/llave.txt"
}

limpiar() {
    passwd -l guardia >/dev/null 2>&1 || true
    como_jugador rm -rf "$DIR"
    rm -rf "$BOVEDA"
}

comprobar() { exit 0; }

despachar "$@"
