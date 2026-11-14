#!/usr/bin/python3 -I
"""ScapeLinux: verificador del juego.

El jugador lo ejecuta con el comando `verificar`, que lo llama con sudo.
Valida las llaves y el estado del sistema, entrega pistas, calcula el puntaje
y prepara cada nivel cuando se desbloquea. Guarda todo en SQLite.

Uso:
    verificar                     Muestra el menú y el nivel actual
    verificar LLAVE               Entrega la llave del nivel actual
    verificar --pista             Pide una pista (resta puntos)
    verificar --estado            Muestra niveles, puntaje y tiempo
    verificar --reiniciar-nivel   Recrea el nivel actual con una llave nueva
    verificar --final             Comprueba la fuga del nivel 6
    verificar --nueva-partida     Abandona la partida y empieza otra
"""

import hashlib
import hmac
import os
import re
import secrets
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Rutas del juego en la VM Servidor. Las pruebas las cambian por carpetas temporales.
RAIZ = Path("/opt/scapelinux")
NIVELES = RAIZ / "niveles"
BD = Path("/var/lib/scapelinux/scapelinux.db")
MARCA_INSTALADO = Path("/etc/scapelinux/instalado")
ENTORNO = {"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LANG": "C.UTF-8"}

ESPERA_FALLO = 5        # segundos de espera tras una llave incorrecta
PENALIZACION_FALLO = 5  # puntos por cada intento fallido
TOTAL_NIVELES = 6
FORMATO_LLAVE = re.compile(r"^[0-9A-F]{4}-[0-9A-F]{4}$")

INSTRUCCIONES = {
    1: ["La pista está escondida en una de las salas de ~/nivel1.",
        "Los archivos ocultos no aparecen con un ls normal."],
    2: ["La llave está en /srv/scapelinux/nivel2/puerta.txt, pero no puedes leerla.",
        "Revisa su dueño y sus permisos. Tienes permiso de sudo solo para:",
        "  sudo chown jugador /srv/scapelinux/nivel2/puerta.txt"],
    3: ["Un proceso llamado puerta_bloqueada retiene la puerta.",
        "Encuéntralo y detenlo. La llave aparecerá en ~/nivel3/llave.txt."],
    4: ["La llave está en /srv/scapelinux/boveda, que solo abre el grupo boveda.",
        "En ~/nivel4 hay una nota que puede ayudarte a cambiar de identidad."],
    5: ["Los accesos quedan registrados en /var/log/scapelinux/accesos.log.",
        "Ahí hay muchas llaves, pero solo una está ACTIVA."],
    6: ["Programa con cron la ejecución de /opt/scapelinux/bin/fuga.",
        "Cuando cron la haya ejecutado, escribe: verificar --final"],
}


class ErrorJuego(Exception):
    """Error que se muestra al jugador sin traza."""


# ----------------------------------------------------------------- utilidades

def ahora():
    return datetime.now(timezone.utc).replace(microsecond=0)


def texto_fecha(fecha):
    return fecha.strftime("%Y-%m-%d %H:%M:%S")


def leer_fecha(texto):
    return datetime.strptime(texto, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)


def generar_llave():
    return f"{secrets.token_hex(2)}-{secrets.token_hex(2)}".upper()


def hash_llave(llave):
    return hashlib.sha256(llave.encode("utf-8")).hexdigest()


def normalizar_llave(texto):
    """Devuelve la llave en mayúsculas o None si no tiene el formato XXXX-XXXX."""
    llave = texto.strip().upper()
    return llave if FORMATO_LLAVE.match(llave) else None


def calcular_puntos(puntos_max, penalizacion_pistas, fallos, minutos, objetivo):
    """puntos = máx(0, máximo − pistas − 5 × fallos − minutos sobre el objetivo)."""
    exceso = max(0, minutos - objetivo)
    return max(0, puntos_max - penalizacion_pistas - PENALIZACION_FALLO * fallos - exceso)


def ejecutar_nivel(numero, accion, *argumentos, llave=None):
    """Ejecuta nivelN.sh. La llave viaja por la entrada estándar, no como argumento."""
    script = NIVELES / f"nivel{numero}.sh"
    resultado = subprocess.run(
        ["/bin/bash", str(script), accion, *argumentos],
        input=(llave or "") + "\n", capture_output=True, text=True, env=ENTORNO, check=False,
    )
    return resultado.returncode, (resultado.stdout + resultado.stderr).strip()


def preparar_nivel(numero, llave):
    codigo, salida = ejecutar_nivel(numero, "preparar", llave=llave)
    if codigo != 0:
        raise ErrorJuego(f"No se pudo preparar el nivel {numero}: {salida}")


def limpiar_nivel(numero):
    ejecutar_nivel(numero, "limpiar")


# --------------------------------------------------------------- base de datos

def conectar():
    con = sqlite3.connect(BD)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    return con


def id_jugador(con, usuario):
    fila = con.execute("SELECT id FROM jugador WHERE usuario = ?", (usuario,)).fetchone()
    if fila:
        return fila["id"]
    cur = con.execute("INSERT INTO jugador (usuario, nombre, creado_en) VALUES (?, ?, ?)",
                      (usuario, usuario, texto_fecha(ahora())))
    return cur.lastrowid


def partida_activa(con, jugador_id):
    return con.execute(
        "SELECT * FROM partida WHERE jugador_id = ? AND estado = 'en_curso' ORDER BY id DESC LIMIT 1",
        (jugador_id,)).fetchone()


def nivel_actual(con, partida_id):
    return con.execute(
        """SELECT p.*, n.numero, n.titulo, n.puntos_max, n.tiempo_objetivo_min
           FROM progreso_nivel p JOIN nivel n ON n.id = p.nivel_id
           WHERE p.partida_id = ? AND p.estado = 'en_juego'
           ORDER BY n.numero LIMIT 1""", (partida_id,)).fetchone()


def desbloquear(con, partida_id, numero):
    nivel = con.execute("SELECT id FROM nivel WHERE numero = ?", (numero,)).fetchone()
    llave = generar_llave()
    preparar_nivel(numero, llave)
    con.execute(
        """INSERT INTO progreso_nivel (partida_id, nivel_id, estado, inicio, llave_hash)
           VALUES (?, ?, 'en_juego', ?, ?)
           ON CONFLICT (partida_id, nivel_id) DO UPDATE
           SET estado = 'en_juego', inicio = excluded.inicio, llave_hash = excluded.llave_hash""",
        (partida_id, nivel["id"], texto_fecha(ahora()), hash_llave(llave)))


def nueva_partida(con, jugador_id):
    for numero in range(1, TOTAL_NIVELES + 1):
        limpiar_nivel(numero)
    cur = con.execute("INSERT INTO partida (jugador_id, inicio) VALUES (?, ?)",
                      (jugador_id, texto_fecha(ahora())))
    for nivel in con.execute("SELECT id FROM nivel ORDER BY numero"):
        con.execute("INSERT INTO progreso_nivel (partida_id, nivel_id) VALUES (?, ?)",
                    (cur.lastrowid, nivel["id"]))
    desbloquear(con, cur.lastrowid, 1)
    return con.execute("SELECT * FROM partida WHERE id = ?", (cur.lastrowid,)).fetchone()


def obtener_partida(con, usuario, crear=True):
    jugador_id = id_jugador(con, usuario)
    partida = partida_activa(con, jugador_id)
    if partida is None and crear:
        partida = nueva_partida(con, jugador_id)
        print("Comienza una nueva partida.\n")
    return partida


def registrar_intento(con, partida_id, nivel_id, correcto):
    con.execute("INSERT INTO intento (partida_id, nivel_id, correcto, fecha) VALUES (?, ?, ?, ?)",
                (partida_id, nivel_id, 1 if correcto else 0, texto_fecha(ahora())))


def fallar_intento(con, partida_id, nivel_id, mensaje):
    registrar_intento(con, partida_id, nivel_id, False)
    con.commit()
    time.sleep(ESPERA_FALLO)
    raise ErrorJuego(f"✘ {mensaje} (-{PENALIZACION_FALLO} pts)")


def completar(con, partida, actual):
    """Marca el nivel como superado, calcula sus puntos y desbloquea el siguiente."""
    fallos = con.execute(
        "SELECT COUNT(*) FROM intento WHERE partida_id = ? AND nivel_id = ? AND correcto = 0",
        (partida["id"], actual["nivel_id"])).fetchone()[0]
    pistas = con.execute(
        """SELECT COALESCE(SUM(pi.penalizacion), 0) FROM pista_usada pu
           JOIN pista pi ON pi.id = pu.pista_id
           WHERE pu.partida_id = ? AND pi.nivel_id = ?""",
        (partida["id"], actual["nivel_id"])).fetchone()[0]
    fin = ahora()
    minutos = int((fin - leer_fecha(actual["inicio"])).total_seconds() // 60)
    puntos = calcular_puntos(actual["puntos_max"], pistas, fallos, minutos, actual["tiempo_objetivo_min"])
    registrar_intento(con, partida["id"], actual["nivel_id"], True)
    con.execute(
        """UPDATE progreso_nivel SET estado = 'superado', fin = ?, puntos = ?
           WHERE partida_id = ? AND nivel_id = ?""",
        (texto_fecha(fin), puntos, partida["id"], actual["nivel_id"]))
    total = con.execute("SELECT COALESCE(SUM(puntos), 0) FROM progreso_nivel WHERE partida_id = ?",
                        (partida["id"],)).fetchone()[0]
    con.execute("UPDATE partida SET puntaje_total = ? WHERE id = ?", (total, partida["id"]))
    print(f"✔ Nivel {actual['numero']} superado: {puntos} pts "
          f"({minutos} min, {fallos} fallos, -{pistas} por pistas). Total: {total} pts")
    if actual["numero"] < TOTAL_NIVELES:
        desbloquear(con, partida["id"], actual["numero"] + 1)
        con.commit()
        siguiente = nivel_actual(con, partida["id"])
        print(f"★ Nivel {siguiente['numero']} desbloqueado\n")
        mostrar_nivel(siguiente)
    return total


# ------------------------------------------------------------------- comandos

def mostrar_nivel(actual):
    print(f"== NIVEL {actual['numero']}: {actual['titulo']} ==")
    for linea in INSTRUCCIONES[actual["numero"]]:
        print(linea)


def requerir_nivel(con, partida):
    actual = nivel_actual(con, partida["id"])
    if actual is None:
        raise ErrorJuego("No hay un nivel en juego. Usa verificar --nueva-partida.")
    return actual


def cmd_bienvenida(con, usuario):
    print("=" * 52)
    print("  SCAPELINUX - Estás encerrado en un sistema Linux")
    print("  Solo escaparás usando el sistema operativo.")
    print("=" * 52)
    print("Comandos: verificar LLAVE | --pista | --estado | --reiniciar-nivel | --final\n")
    partida = obtener_partida(con, usuario)
    con.commit()
    mostrar_nivel(requerir_nivel(con, partida))


def cmd_llave(con, usuario, texto):
    partida = obtener_partida(con, usuario, crear=False)
    if partida is None:
        raise ErrorJuego("No tienes una partida activa. Escribe: verificar")
    actual = requerir_nivel(con, partida)
    if actual["numero"] == TOTAL_NIVELES:
        raise ErrorJuego("El nivel 6 no tiene llave: cuando cron ejecute la fuga, escribe verificar --final")
    llave = normalizar_llave(texto)
    if llave is None:
        fallar_intento(con, partida["id"], actual["nivel_id"], "La llave debe tener el formato XXXX-XXXX.")
    if not hmac.compare_digest(hash_llave(llave), actual["llave_hash"]):
        fallar_intento(con, partida["id"], actual["nivel_id"], "Llave incorrecta.")
    codigo, mensaje = ejecutar_nivel(actual["numero"], "comprobar")
    if codigo != 0:
        fallar_intento(con, partida["id"], actual["nivel_id"], f"La llave es correcta, pero falta algo: {mensaje}")
    completar(con, partida, actual)
    con.commit()


def cmd_final(con, usuario):
    partida = obtener_partida(con, usuario, crear=False)
    if partida is None:
        raise ErrorJuego("No tienes una partida activa. Escribe: verificar")
    actual = requerir_nivel(con, partida)
    if actual["numero"] != TOTAL_NIVELES:
        raise ErrorJuego(f"Todavía estás en el nivel {actual['numero']}.")
    desde = str(int(leer_fecha(actual["inicio"]).timestamp()))
    codigo, mensaje = ejecutar_nivel(TOTAL_NIVELES, "comprobar", desde)
    if codigo != 0:
        fallar_intento(con, partida["id"], actual["nivel_id"], mensaje)
    total = completar(con, partida, actual)
    fin = ahora()
    con.execute("UPDATE partida SET estado = 'escapado', fin = ? WHERE id = ?", (texto_fecha(fin), partida["id"]))
    con.commit()
    minutos = int((fin - leer_fecha(partida["inicio"])).total_seconds() // 60)
    print("\n*** ¡ESCAPASTE! ***")
    print(f"Jugador: {usuario}\nNiveles: 6/6\nTiempo: {minutos} min\nPuntaje: {total} pts")


def cmd_pista(con, usuario):
    partida = obtener_partida(con, usuario)
    actual = requerir_nivel(con, partida)
    pista = con.execute(
        """SELECT * FROM pista WHERE nivel_id = ? AND id NOT IN
           (SELECT pista_id FROM pista_usada WHERE partida_id = ?) ORDER BY orden LIMIT 1""",
        (actual["nivel_id"], partida["id"])).fetchone()
    if pista is None:
        print("Ya usaste todas las pistas de este nivel.")
        return
    con.execute("INSERT INTO pista_usada (partida_id, pista_id, fecha) VALUES (?, ?, ?)",
                (partida["id"], pista["id"], texto_fecha(ahora())))
    con.commit()
    print(f"Pista {pista['orden']} (-{pista['penalizacion']} pts): {pista['texto']}")


def cmd_estado(con, usuario):
    partida = obtener_partida(con, usuario)
    con.commit()
    minutos = int((ahora() - leer_fecha(partida["inicio"])).total_seconds() // 60)
    print(f"Partida {partida['id']} · {minutos} min · {partida['puntaje_total']} pts\n")
    for fila in con.execute(
            """SELECT n.numero, n.titulo, p.estado, p.puntos FROM progreso_nivel p
               JOIN nivel n ON n.id = p.nivel_id WHERE p.partida_id = ? ORDER BY n.numero""",
            (partida["id"],)):
        print(f"  {fila['numero']}. {fila['titulo']:<24} {fila['estado']:<10} {fila['puntos']} pts")
    print()
    mostrar_nivel(requerir_nivel(con, partida))


def cmd_reiniciar_nivel(con, usuario):
    partida = obtener_partida(con, usuario)
    actual = requerir_nivel(con, partida)
    limpiar_nivel(actual["numero"])
    llave = generar_llave()
    preparar_nivel(actual["numero"], llave)
    con.execute("UPDATE progreso_nivel SET llave_hash = ? WHERE partida_id = ? AND nivel_id = ?",
                (hash_llave(llave), partida["id"], actual["nivel_id"]))
    con.commit()
    print(f"Nivel {actual['numero']} reiniciado con una llave nueva. El tiempo sigue corriendo.\n")
    mostrar_nivel(actual)


def cmd_nueva_partida(con, usuario):
    jugador_id = id_jugador(con, usuario)
    con.execute("UPDATE partida SET estado = 'abandonada', fin = ? WHERE jugador_id = ? AND estado = 'en_curso'",
                (texto_fecha(ahora()), jugador_id))
    partida = nueva_partida(con, jugador_id)
    con.commit()
    print("Nueva partida creada.\n")
    mostrar_nivel(requerir_nivel(con, partida))


COMANDOS = {
    "--bienvenida": cmd_bienvenida,
    "--pista": cmd_pista,
    "--estado": cmd_estado,
    "--reiniciar-nivel": cmd_reiniciar_nivel,
    "--final": cmd_final,
    "--nueva-partida": cmd_nueva_partida,
}


def main(argv):
    if os.geteuid() != 0:
        print("Usa el comando: verificar")
        return 1
    if not MARCA_INSTALADO.exists():
        print("ScapeLinux no está instalado en este equipo.")
        return 1
    usuario = os.environ.get("SUDO_USER") or "jugador"
    if usuario == "root":
        usuario = "jugador"
    argumentos = argv[1:]
    if len(argumentos) > 1:
        print(__doc__)
        return 2
    opcion = argumentos[0] if argumentos else "--bienvenida"
    con = conectar()
    try:
        if opcion in ("-h", "--ayuda"):
            print(__doc__)
        elif opcion in COMANDOS:
            COMANDOS[opcion](con, usuario)
        elif opcion.startswith("-"):
            print(__doc__)
            return 2
        else:
            cmd_llave(con, usuario, opcion)
    except ErrorJuego as error:
        print(error)
        return 1
    finally:
        con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
