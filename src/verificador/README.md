# Verificador

`scapelinux.py` es el programa que usa el jugador mediante el comando `verificar`, que lo ejecuta con `sudo`. Usa solo la biblioteca estándar de Python 3.

| Comando | Función |
|---|---|
| `verificar` | Muestra el menú y crea una partida si no hay ninguna |
| `verificar LLAVE` | Valida la llave y el estado del sistema, y desbloquea el siguiente nivel |
| `verificar --pista` | Muestra la siguiente pista y registra su penalización |
| `verificar --estado` | Muestra niveles, puntaje y tiempo |
| `verificar --reiniciar-nivel` | Recrea el nivel actual con una llave nueva |
| `verificar --final` | Comprueba el nivel 6 y muestra el resultado |
| `verificar --nueva-partida` | Abandona la partida actual y empieza otra |

## Decisiones de seguridad

- Las llaves se generan con `secrets` y en la base solo se guarda su hash SHA-256. Se comparan con `hmac.compare_digest`.
- Una llave debe tener el formato `XXXX-XXXX`. Cualquier otro argumento se rechaza antes de tocar la base.
- Todas las consultas SQL usan parámetros.
- Cada intento fallido espera 5 segundos y resta 5 puntos.
- Se ejecuta con `python3 -I`, que ignora variables de entorno y carpetas del usuario.
- Los scripts de nivel reciben un `PATH` fijo y la llave por la entrada estándar.

## Puntaje

```text
puntos = máx(0, puntos_max − pistas − 5 × intentos fallidos − minutos sobre 15)
```
