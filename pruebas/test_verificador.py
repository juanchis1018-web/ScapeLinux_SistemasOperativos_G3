"""Pruebas unitarias del verificador de ScapeLinux.

No necesitan la VM ni permisos de root: reemplazan los scripts de nivel por
versiones de prueba y usan una base de datos temporal.
Uso, desde la raíz del repositorio: python3 -m unittest discover -s pruebas -v
"""
import contextlib
import io
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

RAIZ_REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ_REPO / "src" / "verificador"))
import scapelinux as sl  # noqa: E402

NIVEL_FALSO = """#!/bin/bash
case "$1" in
  preparar) read -r k; echo "$k" > "{dir}/llave$N" ;;
  comprobar) [ -f "{dir}/fallar$N" ] && {{ echo "estado incorrecto"; exit 1; }}; exit 0 ;;
  limpiar) rm -f "{dir}/llave$N" ;;
esac
"""


class PruebasFunciones(unittest.TestCase):
    def test_puntaje_ejemplo_del_readme(self):
        # Nivel 3: 150 pts, una pista (10), un fallo (5) y 18 minutos con objetivo de 15.
        self.assertEqual(sl.calcular_puntos(150, 10, 1, 18, 15), 132)

    def test_puntaje_nunca_negativo(self):
        self.assertEqual(sl.calcular_puntos(100, 20, 30, 90, 15), 0)

    def test_formato_de_llave(self):
        self.assertEqual(sl.normalizar_llave(" 7f3a-k3b1 "), None)
        self.assertEqual(sl.normalizar_llave("7f3a-0b1c"), "7F3A-0B1C")
        self.assertIsNone(sl.normalizar_llave("1'; DROP TABLE nivel;--"))

    def test_llaves_aleatorias(self):
        llaves = {sl.generar_llave() for _ in range(200)}
        self.assertEqual(len(llaves), 200)
        self.assertTrue(all(sl.FORMATO_LLAVE.match(k) for k in llaves))


class PruebasPartida(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = Path(self.tmp.name)
        (d / "niveles").mkdir()
        for n in range(1, 7):
            (d / "niveles" / f"nivel{n}.sh").write_text(
                f"N={n}\n" + NIVEL_FALSO.format(dir=d).replace("#!/bin/bash\n", ""))
        sl.NIVELES, sl.BD, sl.ESPERA_FALLO = d / "niveles", d / "prueba.db", 0
        con = sqlite3.connect(sl.BD)
        con.executescript((RAIZ_REPO / "src/base_datos/esquema.sql").read_text(encoding="utf-8"))
        con.close()
        self.dir = d
        self.con = sl.conectar()

    def tearDown(self):
        self.con.close()
        self.tmp.cleanup()

    def llave(self, n):
        return (self.dir / f"llave{n}").read_text().strip()

    def correr(self, funcion, *args):
        with contextlib.redirect_stdout(io.StringIO()) as salida:
            funcion(self.con, "jugador", *args)
        return salida.getvalue()

    def nivel(self):
        return sl.nivel_actual(self.con, sl.partida_activa(self.con, 1)["id"])["numero"]

    def test_llave_correcta_desbloquea_el_siguiente_nivel(self):
        self.correr(sl.cmd_bienvenida)
        self.correr(sl.cmd_llave, self.llave(1))
        self.assertEqual(self.nivel(), 2)

    def test_llave_incorrecta_se_rechaza_y_cuenta_como_fallo(self):
        self.correr(sl.cmd_bienvenida)
        with self.assertRaises(sl.ErrorJuego):
            self.correr(sl.cmd_llave, "0000-0000")
        self.assertEqual(self.nivel(), 1)
        fallos = self.con.execute("SELECT COUNT(*) FROM intento WHERE correcto = 0").fetchone()[0]
        self.assertEqual(fallos, 1)

    def test_llave_de_otra_partida_no_sirve(self):
        self.correr(sl.cmd_bienvenida)
        vieja = self.llave(1)
        self.correr(sl.cmd_nueva_partida)
        with self.assertRaises(sl.ErrorJuego):
            self.correr(sl.cmd_llave, vieja)

    def test_reiniciar_nivel_invalida_la_llave_anterior(self):
        self.correr(sl.cmd_bienvenida)
        vieja = self.llave(1)
        self.correr(sl.cmd_reiniciar_nivel)
        with self.assertRaises(sl.ErrorJuego):
            self.correr(sl.cmd_llave, vieja)

    def test_llave_correcta_sin_el_estado_esperado_no_aprueba(self):
        self.correr(sl.cmd_bienvenida)
        (self.dir / "fallar1").touch()
        with self.assertRaises(sl.ErrorJuego):
            self.correr(sl.cmd_llave, self.llave(1))
        self.assertEqual(self.nivel(), 1)

    def test_pista_resta_puntos(self):
        self.correr(sl.cmd_bienvenida)
        self.correr(sl.cmd_pista)
        salida = self.correr(sl.cmd_llave, self.llave(1))
        self.assertIn("Nivel 1 superado: 90 pts", salida)

    def test_partida_completa(self):
        self.correr(sl.cmd_bienvenida)
        for n in range(1, 6):
            self.correr(sl.cmd_llave, self.llave(n))
        salida = self.correr(sl.cmd_final)
        self.assertIn("ESCAPASTE", salida)
        self.assertIn("Puntaje: 1000 pts", salida)


if __name__ == "__main__":
    unittest.main()
