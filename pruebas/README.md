# Plan de pruebas

Estas pruebas se ejecutarán en las VMs durante la semana 4. Los resultados se registrarán aquí.

| ID | Prueba | Resultado esperado | Estado |
|---|---|---|---|
| P1 | Ejecutar `comprobar_entorno.sh` en un equipo real | Se detiene con un aviso | Probado fuera de una VM |
| P2 | Ejecutar `comprobar_entorno.sh` en cada VM | Confirma el entorno | Pendiente |
| P3 | Crear la base con `esquema.sql` | Crea 7 tablas y 6 niveles | Probado en SQLite |
| P4 | Conectar por SSH desde la VM Jugador | La conexión funciona | Pendiente |
| P5 | Resolver cada nivel | Se entrega y valida la llave | Pendiente |
| P6 | Ingresar una llave de otra partida | Se rechaza | Pendiente |
| P7 | Crear a mano la evidencia del nivel 6 | No se aprueba el nivel | Pendiente |
| P8 | Leer la base de datos como `jugador` | El sistema niega el acceso | Pendiente |
| P9 | Probar las reglas de `sudo` con sudo-rs | Solo permiten lo definido | Pendiente |
| P10 | Reiniciar un nivel dañado | Se recrea con una llave nueva | Pendiente |
| P11 | Restaurar el snapshot y medir el tiempo | Termina en menos de un minuto | Pendiente |
| P12 | Importar el `.ova` y crear el snapshot | El juego queda listo | Pendiente |
