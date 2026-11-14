# Niveles

Cada nivel es un script Bash que el verificador ejecuta como root con una de tres acciones:

| Acción | Qué hace |
|---|---|
| `preparar` | Crea el reto. Recibe la llave por la entrada estándar para que no aparezca en `ps` |
| `limpiar` | Borra el reto |
| `comprobar` | Revisa el estado del sistema. Sale con 0 si el reto se hizo, o con 1 y un mensaje si falta algo |

| Script | Reto | Lo que crea | Lo que comprueba |
|---|---|---|---|
| `nivel1.sh` | Archivos ocultos | Cinco salas en `~/nivel1` y un archivo oculto con la llave en una sala al azar | Solo la llave |
| `nivel2.sh` | Permisos | `/srv/scapelinux/nivel2/puerta.txt` de root con permisos `000` | Que el dueño sea `jugador` y tenga lectura |
| `nivel3.sh` | Procesos | Inicia `scapelinux-puerta.service`, que corre `puerta_bloqueada` como `jugador` | Que el servicio esté inactivo |
| `nivel4.sh` | Usuarios y grupos | Nueva contraseña de `guardia`, una nota con ella y la llave en `/srv/scapelinux/boveda` (`root:boveda`, `640`) | Solo la llave |
| `nivel5.sh` | Logs | `/var/log/scapelinux/accesos.log` con 3000 líneas, llaves revocadas y una activa | Solo la llave |
| `nivel6.sh` | Cron | La carpeta `~/nivel6` | Tarea en el `crontab`, registro de la fuga y ejecución en el registro de cron |

Programas auxiliares en `bin/`:

| Programa | Uso |
|---|---|
| `puerta_bloqueada` | Proceso del nivel 3. Termina con `kill` |
| `abrir_puerta` | systemd lo ejecuta como root al terminar el proceso y escribe la llave en `~/nivel3/llave.txt` |
| `fuga` | Lo que el jugador debe programar con cron en el nivel 6 |

`comun.sh` reúne las funciones comunes. Todo lo que se crea o borra en la carpeta del jugador se hace como `jugador`, para que un enlace simbólico no pueda llevar a root a modificar otro archivo.
