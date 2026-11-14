-- ScapeLinux: base de datos del verificador (SQLite 3)
-- Guarda jugadores, partidas, progreso, intentos y pistas usadas.
-- Crear la base: sqlite3 scapelinux.db < esquema.sql

PRAGMA foreign_keys = ON;

CREATE TABLE jugador (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario     TEXT NOT NULL UNIQUE,
    nombre      TEXT NOT NULL,
    creado_en   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE nivel (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    numero      INTEGER NOT NULL UNIQUE CHECK (numero BETWEEN 1 AND 6),
    titulo      TEXT NOT NULL,
    tema        TEXT NOT NULL,
    comandos    TEXT NOT NULL,
    puntos_max  INTEGER NOT NULL CHECK (puntos_max > 0),
    tiempo_objetivo_min INTEGER NOT NULL DEFAULT 15 CHECK (tiempo_objetivo_min > 0)
);

CREATE TABLE pista (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    nivel_id     INTEGER NOT NULL REFERENCES nivel(id) ON DELETE CASCADE,
    orden        INTEGER NOT NULL CHECK (orden > 0),
    texto        TEXT NOT NULL,
    penalizacion INTEGER NOT NULL DEFAULT 10 CHECK (penalizacion >= 0),
    UNIQUE (nivel_id, orden)
);

CREATE TABLE partida (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador_id    INTEGER NOT NULL REFERENCES jugador(id),
    inicio        TEXT NOT NULL DEFAULT (datetime('now')),
    fin           TEXT,
    estado        TEXT NOT NULL DEFAULT 'en_curso'
                  CHECK (estado IN ('en_curso', 'escapado', 'abandonada')),
    puntaje_total INTEGER NOT NULL DEFAULT 0 CHECK (puntaje_total >= 0)
);

CREATE TABLE progreso_nivel (
    partida_id  INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    nivel_id    INTEGER NOT NULL REFERENCES nivel(id),
    estado      TEXT NOT NULL DEFAULT 'bloqueado'
                CHECK (estado IN ('bloqueado', 'en_juego', 'llave_obtenida', 'superado')),
    inicio      TEXT,
    fin         TEXT,
    puntos      INTEGER NOT NULL DEFAULT 0 CHECK (puntos >= 0),
    llave_hash  TEXT,             -- SHA-256 de la llave, distinta en cada partida
    PRIMARY KEY (partida_id, nivel_id)
);

CREATE TABLE intento (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    partida_id  INTEGER NOT NULL,
    nivel_id    INTEGER NOT NULL,
    correcto    INTEGER NOT NULL CHECK (correcto IN (0, 1)),
    fecha       TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (partida_id, nivel_id)
        REFERENCES progreso_nivel(partida_id, nivel_id) ON DELETE CASCADE
);

CREATE TABLE pista_usada (
    partida_id  INTEGER NOT NULL REFERENCES partida(id) ON DELETE CASCADE,
    pista_id    INTEGER NOT NULL REFERENCES pista(id),
    fecha       TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (partida_id, pista_id)
);

INSERT INTO nivel (numero, titulo, tema, comandos, puntos_max) VALUES
    (1, 'La pista escondida',    'Archivos ocultos',      'ls -a, find',     100),
    (2, 'El archivo bloqueado',  'Permisos y dueños',     'chmod, chown',    120),
    (3, 'El proceso bloqueador', 'Procesos y señales',    'ps, kill',        150),
    (4, 'La otra identidad',     'Usuarios y grupos',     'su, groups',      170),
    (5, 'El rastro en los logs', 'Registros del sistema', 'grep, /var/log',  200),
    (6, 'La fuga final',         'Tareas programadas',    'cron',            260);

-- Dos pistas por nivel. Cada pista resta 10 puntos del nivel.
INSERT INTO pista (nivel_id, orden, texto) VALUES
    (1, 1, 'Los archivos que empiezan con punto no aparecen con ls. Prueba ls -a dentro de cada sala.'),
    (1, 2, 'find ~/nivel1 -type f -name ".*" lista todos los archivos ocultos. Luego usa cat.'),
    (2, 1, 'Mira el dueño y los permisos con ls -l /srv/scapelinux/nivel2.'),
    (2, 2, 'Primero: sudo chown jugador /srv/scapelinux/nivel2/puerta.txt. Después: chmod u+r y cat.'),
    (3, 1, 'ps aux muestra todos los procesos. Filtra con grep puerta.'),
    (3, 2, 'kill seguido del PID detiene el proceso. Luego revisa ~/nivel3/llave.txt.'),
    (4, 1, 'Lee la nota de ~/nivel4. Con su guardia cambias de usuario.'),
    (4, 2, 'Como guardia, groups muestra el grupo boveda. La llave está en /srv/scapelinux/boveda.'),
    (5, 1, 'El log solo lo lee el grupo boveda: vuelve a entrar como guardia.'),
    (5, 2, 'Hay muchas llaves revocadas. grep ACTIVA /var/log/scapelinux/accesos.log muestra la buena.'),
    (6, 1, 'crontab -e abre tus tareas programadas. La línea "* * * * * comando" se ejecuta cada minuto.'),
    (6, 2, 'Agrega: * * * * * /opt/scapelinux/bin/fuga. Espera un minuto y ejecuta verificar --final.');
