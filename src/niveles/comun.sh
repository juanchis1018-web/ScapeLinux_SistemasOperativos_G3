# ScapeLinux: funciones comunes de los niveles.
# Los niveles los ejecuta el verificador como root. Todo lo que se crea o se
# borra dentro de la carpeta del jugador se hace con la identidad de jugador,
# para que un enlace simbólico puesto por él no lleve a root a tocar otro archivo.

JUGADOR="jugador"
HOME_J="/home/$JUGADOR"
SRV="/srv/scapelinux"
DATOS="/var/lib/scapelinux"

como_jugador() { runuser -u "$JUGADOR" -- "$@"; }

# Escribe la entrada estándar en un archivo, como jugador.
escribir_como_jugador() { como_jugador sh -c 'cat > "$1"' _ "$1"; }

# Borra y vuelve a crear una carpeta de nivel dentro del home del jugador.
carpeta_nueva() {
    como_jugador rm -rf "$1"
    como_jugador mkdir -p "$1"
}

# La llave llega por la entrada estándar para que no aparezca en ps.
leer_llave() { IFS= read -r LLAVE || true; [[ -n "${LLAVE:-}" ]] || { echo "Falta la llave"; exit 2; }; }

aleatorio() { od -An -N"${1:-3}" -tx1 /dev/urandom | tr -d ' \n'; }

fallar() { echo "$1"; exit 1; }

despachar() {
    case "${1:-}" in
        preparar|limpiar|comprobar) accion="$1"; shift; "$accion" "$@" ;;
        *) echo "Uso: $0 preparar|limpiar|comprobar"; exit 2 ;;
    esac
}
