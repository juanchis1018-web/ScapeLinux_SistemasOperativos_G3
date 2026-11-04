#!/usr/bin/env bash
# ScapeLinux: comprueba que el equipo sea una VM de VirtualBox con lo necesario.
# Uso: bash comprobar_entorno.sh servidor | jugador
# Los scripts de instalación deben ejecutarlo primero y detenerse si falla.

set -u

rol="${1:-}"
case "$rol" in
    servidor) comandos="bash python3 sqlite3 sshd cron systemctl ps kill find grep chmod chown su groups crontab sudo" ;;
    jugador)  comandos="bash ssh" ;;
    *) echo "Uso: $0 servidor|jugador"; exit 2 ;;
esac

virt="$(systemd-detect-virt 2>/dev/null || true)"
if [ "$virt" != "oracle" ]; then
    echo "DETENIDO: este equipo no es una VM de VirtualBox (detectado: ${virt:-desconocido})."
    echo "ScapeLinux no modifica equipos reales."
    exit 1
fi

faltantes=0
for comando in $comandos; do
    # Se incluye /usr/sbin porque ahí está sshd y no siempre figura en el PATH.
    if ! PATH="$PATH:/usr/sbin:/sbin" command -v "$comando" >/dev/null 2>&1; then
        echo "FALTA: $comando"
        faltantes=$((faltantes + 1))
    fi
done

if [ "$faltantes" -gt 0 ]; then
    echo "Entorno incompleto: faltan $faltantes comandos."
    exit 3
fi

echo "Entorno correcto para el rol: $rol"
. /etc/os-release 2>/dev/null && echo "Sistema: ${PRETTY_NAME:-desconocido}"
echo "Kernel: $(uname -r)"
