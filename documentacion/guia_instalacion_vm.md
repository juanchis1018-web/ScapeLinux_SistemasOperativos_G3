# Guía de instalación de las VMs

Esta guía monta ScapeLinux en VirtualBox sobre Windows 10/11. Se hace una sola vez y toma cerca de una hora, la mayor parte esperando instalaciones.

## 1. Lo que se necesita

| Elemento | Dónde conseguirlo |
|---|---|
| Oracle VirtualBox | https://www.virtualbox.org/wiki/Downloads |
| Ubuntu Server 26.04 LTS (ISO) | https://ubuntu.com/download/server |
| Debian 13 netinst (ISO) | https://www.debian.org/distrib/netinst |

El equipo debe tener la virtualización (VT-x o AMD-V) activada en la BIOS y al menos 8 GB de RAM.

## 2. Crear la VM Servidor

1. En VirtualBox pulsa **Nueva**.
2. Nombre: `ScapeLinux-Servidor`. Imagen ISO: la de Ubuntu Server. Marca **Omitir instalación desatendida**.
3. Memoria: **2048 MB**, procesadores: **2**, disco: **15 GB**.
4. Antes de encenderla, abre **Configuración > Red**:
   - **Adaptador 1:** NAT. Sirve para descargar paquetes durante la instalación.
   - **Adaptador 2:** marca **Habilitar**, elige **Red interna** y escribe el nombre `scapelinux`.
5. Enciéndela e instala Ubuntu Server con las opciones por defecto:
   - Usuario administrador: por ejemplo `admin`. **No** lo llames `jugador` ni `guardia`.
   - Marca **Install OpenSSH server**.
6. Al terminar, reinicia y entra con el usuario `admin`.

### Dirección de la red interna

Mira el nombre de la segunda tarjeta de red. Suele ser `enp0s8`:

```text
ip -br a
```

Crea su configuración (cambia `enp0s8` si tu tarjeta tiene otro nombre):

```text
sudo nano /etc/netplan/60-scapelinux.yaml
```

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      addresses: [192.168.56.10/24]
```

Guarda con Ctrl+O, Enter y Ctrl+X. Luego:

```text
sudo chmod 600 /etc/netplan/60-scapelinux.yaml
sudo netplan apply
ip -br a
```

Debe aparecer `192.168.56.10` en `enp0s8`.

## 3. Instalar ScapeLinux en la VM Servidor

```text
sudo apt update
sudo apt install -y git openssh-server cron sqlite3
git clone https://github.com/juanchis1018-web/ScapeLinux_SistemasOperativos_G3.git
cd ScapeLinux_SistemasOperativos_G3/src
sudo bash instalar.sh
```

El instalador pide la contraseña del usuario `jugador`, que se usará para entrar por SSH. Al final debe decir **ScapeLinux quedó instalado**.

Ejecuta la prueba integral. Tarda unos 2 minutos:

```text
cd ../pruebas
sudo bash prueba_integral.sh
```

Debe terminar con **21 correctas, 0 fallidas**. El resultado queda guardado en un archivo `resultado_prueba_...txt` dentro de `pruebas`.

## 4. Crear la VM Jugador

1. **Nueva**, nombre `ScapeLinux-Jugador`, ISO de Debian 13, **Omitir instalación desatendida**.
2. Memoria: **2048 MB**, disco: **10 GB**.
3. **Configuración > Red**: igual que el servidor. Adaptador 1 en NAT y Adaptador 2 en **Red interna** `scapelinux`.
4. Instala Debian. En la selección de programas deja solo **utilidades estándar del sistema**. Si prefieres escritorio, marca **LXQt**.
5. Entra con tu usuario, cámbiate a root con `su -` y configura la red interna:

```text
ip -br a
nano /etc/network/interfaces
```

Agrega al final (cambia `enp0s8` si es otro nombre):

```text
auto enp0s8
iface enp0s8 inet static
    address 192.168.56.20/24
```

```text
systemctl restart networking
ping -c 3 192.168.56.10
```

El `ping` debe responder.

## 5. Jugar

Desde la VM Jugador:

```text
ssh jugador@192.168.56.10
```

Escribe `yes` la primera vez y luego la contraseña de `jugador`. Debe aparecer el menú de ScapeLinux con el nivel 1.

## 6. Aislar las VMs

Con las dos VMs apagadas, en cada una:

1. **Configuración > Red > Adaptador 1:** desmarca **Habilitar** para quitar el NAT.
2. **Configuración > General > Avanzado:** **Portapapeles compartido** y **Arrastrar y soltar** en **Inhabilitado**.
3. **Configuración > Carpetas compartidas:** que no haya ninguna.

Así las VMs solo se ven entre sí por la red interna. Si después necesitas instalar algo, vuelve a habilitar el Adaptador 1.

## 7. Crear el snapshot

1. Apaga la VM Servidor.
2. En VirtualBox, selecciónala, abre **Instantáneas** y pulsa **Tomar**.
3. Nombre: `estado-limpio`.

Para volver a ese estado desde la consola de Windows (en `C:\Program Files\Oracle\VirtualBox`):

```text
VBoxManage controlvm "ScapeLinux-Servidor" poweroff
VBoxManage snapshot "ScapeLinux-Servidor" restore "estado-limpio"
VBoxManage startvm "ScapeLinux-Servidor" --type headless
```

## 8. Capturas para la entrega

Guárdalas en `recursos/imagenes/evidencias/`:

| Archivo sugerido | Qué debe mostrar |
|---|---|
| `vm_configuracion.png` | Las dos VMs en VirtualBox y la red interna `scapelinux` |
| `vm_instalador.png` | El final de `instalar.sh` en la VM Servidor |
| `vm_prueba_integral.png` | El resultado de `prueba_integral.sh` con 21 correctas |
| `vm_ssh_menu.png` | La VM Jugador conectada por SSH, con el menú del juego |
| `vm_nivel3.png` | `ps aux \| grep puerta` y `kill` en el nivel 3 |
| `vm_escape.png` | El mensaje **¡ESCAPASTE!** al terminar el nivel 6 |
| `vm_snapshot.png` | El snapshot `estado-limpio` en VirtualBox |

## 9. Problemas comunes

| Problema | Solución |
|---|---|
| El instalador dice que no es una VM de VirtualBox | Se está ejecutando fuera de la VM. Ejecútalo dentro de `ScapeLinux-Servidor` |
| `FALTA: sshd` o `FALTA: crontab` | `sudo apt install -y openssh-server cron sqlite3` |
| El `ping` no responde | Revisa que el Adaptador 2 de ambas VMs esté en Red interna `scapelinux` y el nombre de la tarjeta en la configuración |
| `ssh: connect ... refused` | En el servidor: `sudo systemctl enable --now ssh` |
| En el nivel 2, `sudo chown` pide contraseña o dice que no está permitido | Envía la salida de `sudo -l -U jugador` y de `readlink -f /usr/bin/chown` |
| El nivel 6 no se aprueba | Espera al menos un minuto después de programar la tarea y revisa `journalctl -u cron` |
| Un nivel quedó dañado | `verificar --reiniciar-nivel` o restaurar el snapshot |
