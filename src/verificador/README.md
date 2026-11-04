# Verificador

Aquí irá el programa en Python 3 que usa el jugador. Todavía no está implementado.

| Comando previsto | Función |
|---|---|
| `verificar LLAVE` | Valida la llave y el estado del sistema, y desbloquea el siguiente nivel |
| `verificar --pista` | Muestra una pista y resta su penalización |
| `verificar --estado` | Muestra nivel, puntaje y tiempo |
| `verificar --reiniciar-nivel` | Recrea el nivel actual con una llave nueva |
| `verificar --final` | Comprueba el nivel 6 y muestra el resultado |

Usará los módulos `sqlite3` y `secrets` de Python, y consultas SQL parametrizadas.
