#!/usr/bin/env bash
# ScapeLinux: instala el juego en la VM Servidor de retos.
# Uso, desde la carpeta src: sudo bash instalar.sh
set -euo pipefail
ORIGEN="$(cd "$(dirname "$0")" && pwd)"
RAIZ="/opt/scapelinux"

[[ $EUID -eq 0 ]] || { echo "Ejecuta: sudo bash instalar.sh"; exit 1; }

echo "== 1. Comprobando que sea una VM de VirtualBox =="
bash "$ORIGEN/scripts/comprobar_entorno.sh" servidor || { echo "Instalación cancelada."; exit 1; }

echo "== 2. Usuarios y grupos =="
if ! id -u jugador >/dev/null 2>&1; then
    useradd -m -s /bin/bash jugador
    echo "Escribe la contraseña del usuario jugador (la usará para entrar por SSH):"
    passwd jugador
fi
groupadd -f boveda
id -u guardia >/dev/null 2>&1 || useradd -m -s /bin/bash guardia
usermod -aG boveda guardia
passwd -l guardia >/dev/null
for u in jugador guardia; do
    id -nG "$u" | grep -qw sudo && { echo "AVISO: $u pertenece al grupo sudo. Quítalo con: deluser $u sudo"; exit 1; }
done

echo "== 3. Archivos del juego =="
install -d -m 755 "$RAIZ" "$RAIZ/bin" "$RAIZ/niveles" "$RAIZ/verificador" "$RAIZ/base_datos"
install -m 644 "$ORIGEN/niveles/comun.sh" "$RAIZ/niveles/"
install -m 755 "$ORIGEN"/niveles/nivel?.sh "$RAIZ/niveles/"
install -m 755 "$ORIGEN"/niveles/bin/* "$RAIZ/bin/"
install -m 755 "$ORIGEN/verificador/scapelinux.py" "$RAIZ/verificador/"
install -m 644 "$ORIGEN/base_datos/esquema.sql" "$RAIZ/base_datos/"
install -m 755 "$ORIGEN/config/verificar" /usr/local/bin/verificar
install -m 644 "$ORIGEN/config/scapelinux-puerta.service" /etc/systemd/system/
systemctl daemon-reload
install -d -m 755 -o root -g root /srv/scapelinux
install -d -m 750 -o root -g boveda /var/log/scapelinux
install -d -m 700 -o root -g root /var/lib/scapelinux

echo "== 4. Permisos de sudo =="
visudo -cf "$ORIGEN/config/sudoers_scapelinux"
install -m 440 "$ORIGEN/config/sudoers_scapelinux" /etc/sudoers.d/scapelinux

echo "== 5. Base de datos =="
if [[ ! -f /var/lib/scapelinux/scapelinux.db ]]; then
    python3 -I -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.executescript(open(sys.argv[2],encoding="utf-8").read()); c.commit()' \
        /var/lib/scapelinux/scapelinux.db "$RAIZ/base_datos/esquema.sql"
fi
chmod 600 /var/lib/scapelinux/scapelinux.db

echo "== 6. Menú al iniciar sesión =="
if ! grep -q "scapelinux" /home/jugador/.bashrc 2>/dev/null; then
    printf '\n# scapelinux: menú del juego al entrar\n[ -t 1 ] && verificar --bienvenida\n' \
        | runuser -u jugador -- sh -c 'cat >> "$HOME/.bashrc"'
fi

install -d -m 755 /etc/scapelinux
date '+%Y-%m-%d %H:%M:%S' > /etc/scapelinux/instalado

echo
echo "ScapeLinux quedó instalado."
echo "Siguiente paso: apaga la VM y crea el snapshot estado-limpio en VirtualBox."
