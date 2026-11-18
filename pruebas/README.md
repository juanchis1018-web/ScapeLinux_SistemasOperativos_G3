# Pruebas

## Cómo ejecutarlas

**Pruebas unitarias del verificador.** No necesitan la VM. Desde la raíz del repositorio:

```text
python3 -m unittest discover -s pruebas -v
```

**Prueba integral.** En la VM Servidor, después de instalar. Juega los seis niveles como `jugador` y revisa los controles de seguridad:

```text
sudo bash pruebas/prueba_integral.sh
```

Deja su resultado en `pruebas/resultado_prueba_FECHA.txt`.

## Resultados

| ID | Prueba | Resultado esperado | Estado |
|---|---|---|---|
| P1 | Ejecutar el instalador fuera de una VM de VirtualBox | Se detiene con un aviso | Correcta en entorno Linux |
| P2 | Ejecutar `comprobar_entorno.sh` en cada VM | Confirma el entorno | Correcta en VM Servidor (Ubuntu 26.04.1) |
| P3 | Crear la base con `esquema.sql` | Crea 7 tablas, 6 niveles y 12 pistas | Correcta en entorno Linux y en VM |
| P4 | Conectar por SSH desde la VM Jugador | La conexión funciona y aparece el menú | Pendiente: el menú se probó en la VM con `sudo su - jugador` |
| P5 | Resolver cada nivel | Se entrega y valida la llave | Correcta en entorno Linux y en VM |
| P6 | Ingresar una llave incorrecta, inválida o de otra partida | Se rechaza | Correcta en entorno Linux y en VM |
| P7 | Ejecutar la fuga del nivel 6 a mano | No se aprueba el nivel | Correcta en entorno Linux y en VM |
| P8 | Leer la base de datos como `jugador` | El sistema niega el acceso | Correcta en entorno Linux y en VM |
| P9 | Usar `sudo chown` sobre otro archivo o hacia otro usuario | Se rechaza | Correcta con sudo y con sudo-rs en VM |
| P10 | Reiniciar un nivel | Se recrea con una llave nueva y la anterior deja de servir | Correcta en entorno Linux |
| P11 | Restaurar el snapshot y medir el tiempo | Termina en menos de un minuto | Pendiente |
| P12 | Importar el `.ova` y crear el snapshot | El juego queda listo | Pendiente |

**Pruebas unitarias:** 11 de 11 correctas. Cubren el cálculo del puntaje, el formato y la generación de llaves, el avance de nivel, los fallos, las pistas, el reinicio y una partida completa.

**Prueba integral:** 21 de 21 controles correctos en el entorno Linux de pruebas ([`resultado_prueba_entorno_linux.txt`](resultado_prueba_entorno_linux.txt)) y 21 de 21 en la VM de VirtualBox con Ubuntu Server 26.04.1 LTS, el 17 de noviembre de 2026 ([captura](../recursos/imagenes/evidencias/vm_instalacion_y_prueba_integral.png)).

## Entorno de estas pruebas

Se ejecutaron en un entorno Linux Ubuntu 24.04 con Python 3, sudo, cron y rsyslog reales. Ese entorno no tiene VirtualBox ni systemd, así que se simularon tres elementos:

| Elemento | Cómo se simuló |
|---|---|
| Detección de VirtualBox | Un `systemd-detect-virt` de prueba que responde `oracle` |
| Servicio del nivel 3 | Un `systemctl` de prueba que inicia `puerta_bloqueada` como `jugador` y ejecuta `abrir_puerta` al terminar |
| Registro de cron | Un `journalctl` de prueba que lee las líneas de cron del syslog |

Los simuladores no forman parte del juego ni se instalan en las VMs. En la VM de VirtualBox no se usó ninguna simulación: systemd, cron y la detección de VirtualBox fueron los reales.
