"""
generar_seed.py
Genera el archivo 02_seed_data.sql con:
  - 20.000 usuarios aleatorios (nombres hispanohablantes)
  - Entre 3 y 8 intereses aleatorios por usuario
  - Fechas de nacimiento aleatorias (18 a 70 años)
"""

import random
from faker import Faker
from datetime import date, timedelta

fake = Faker('es_AR')  # Nombres en español argentino
random.seed(42)        # Semilla fija para resultados reproducibles

TOTAL_USUARIOS = 20_000
TOTAL_CATEGORIAS = 35  # Las que cargamos en el seed original

# Hash bcrypt de "password123" — mismo para todos (es seed de prueba)
HASH = '$2b$12$Xgb.BGVAefyQM9QzgbkpNeSc3ZT.l.Nsbic7YWPCwBokYyqyvUySq'

# Bios de ejemplo para asignar aleatoriamente
BIOS = [
    "Apasionado/a por aprender cosas nuevas cada día.",
    "Amante de la música y los viajes.",
    "Fotógrafo/a aficionado/a y cinéfilo/a.",
    "Techie de corazón. Python lover.",
    "Foodie, viajero/a y eterno/a curioso/a.",
    "Fan del deporte y la vida sana.",
    "Emprendedor/a en construcción. Sueño en grande.",
    "Lectora voraz. Café obligatorio.",
    "Gamer y amante del anime.",
    "Diseñador/a UX con alma de artista.",
    "Astrónomo/a aficionado/a. El universo me fascina.",
    "Filosofando desde el sillón.",
    "Cocinero/a de fin de semana. Asador/a de alma.",
    "Runner, yoga y mindfulness.",
    "Sommelier en formación. Vinos mendocinos ❤️",
    None,  # algunos usuarios sin bio
    None,
    None,
]

def fecha_nacimiento_aleatoria():
    """Genera una fecha de nacimiento para alguien de entre 18 y 70 años."""
    hoy = date.today()
    inicio = hoy - timedelta(days=70 * 365)
    fin = hoy - timedelta(days=18 * 365)
    delta = (fin - inicio).days
    return inicio + timedelta(days=random.randint(0, delta))

def generar_usuarios(n):
    emails_usados = set()
    usuarios = []
    for i in range(1, n + 1):
        nombre = fake.first_name()
        apellido = fake.last_name()
        nombre_completo = f"{nombre} {apellido}"

        # Email único
        base_email = f"{nombre.lower().replace(' ', '')}.{apellido.lower().replace(' ', '')}"
        base_email = base_email.replace('á','a').replace('é','e').replace('í','i') \
                               .replace('ó','o').replace('ú','u').replace('ñ','n')
        email = f"{base_email}{i}@example.com"

        bio = random.choice(BIOS)
        fnac = fecha_nacimiento_aleatoria()

        usuarios.append((nombre_completo, email, HASH, bio, fnac))

    return usuarios

def generar_intereses(total_usuarios, total_categorias):
    intereses = []
    for user_id in range(1, total_usuarios + 1):
        cantidad = random.randint(3, 8)
        categorias = random.sample(range(1, total_categorias + 1), cantidad)
        for cat_id in categorias:
            nivel = random.randint(1, 5)
            intereses.append((user_id, cat_id, nivel))
    return intereses

def escribir_sql(usuarios, intereses, path):
    with open(path, 'w', encoding='utf-8') as f:

        f.write("""-- ============================================================
--  02_seed_data.sql  (REGENERADO CON DATOS MASIVOS)
--  Red Social de Recomendaciones - Datos de Prueba
--  Autora: Jime
--  Generado automáticamente con generar_seed.py
--
--  Contenido:
--    · 35 categorías
--    · 20.000 usuarios aleatorios
--    · ~80.000 intereses aleatorios (3-8 por usuario)
-- ============================================================

-- Limpiar datos anteriores de prueba (respeta el orden por FK)
TRUNCATE TABLE user_interests RESTART IDENTITY CASCADE;
TRUNCATE TABLE photos RESTART IDENTITY CASCADE;
TRUNCATE TABLE users RESTART IDENTITY CASCADE;
TRUNCATE TABLE categories RESTART IDENTITY CASCADE;

""")

        # ── CATEGORÍAS (las mismas 35 de antes) ──────────────────────────
        f.write("-- ============================================================\n")
        f.write("-- SECCIÓN 1: CATEGORÍAS\n")
        f.write("-- ============================================================\n\n")
        f.write("INSERT INTO categories (nombre, descripcion, icono) VALUES\n")
        categorias = [
            ("Tecnología",          "Todo sobre software, hardware y tendencias tech",           "laptop"),
            ("Inteligencia Artificial","Machine learning, modelos de lenguaje y automatización","robot"),
            ("Programación",        "Lenguajes, frameworks y buenas prácticas de código",        "code"),
            ("Ciberseguridad",      "Seguridad informática, hacking ético y privacidad",         "shield"),
            ("Videojuegos",         "Gaming, desarrollo de juegos y cultura gamer",              "gamepad"),
            ("Arte Digital",        "Ilustración, diseño gráfico y arte generado por IA",        "palette"),
            ("Fotografía",          "Técnicas, equipos y edición fotográfica",                   "camera"),
            ("Música",              "Géneros musicales, producción y artistas",                  "music"),
            ("Cine y Series",       "Películas, series, análisis y recomendaciones",             "film"),
            ("Literatura",          "Libros, autores, géneros y clubes de lectura",              "book"),
            ("Animación",           "Anime, cartoons, motion graphics y stop motion",            "tv"),
            ("Moda",                "Tendencias, diseño de indumentaria y estilo personal",      "shirt"),
            ("Deportes",            "Fútbol, básquet, tenis y deportes en general",              "trophy"),
            ("Fitness",             "Entrenamiento, gimnasio, rutinas y nutrición deportiva",    "dumbbell"),
            ("Yoga y Meditación",   "Mindfulness, bienestar mental y práctica espiritual",      "heart"),
            ("Outdoor",             "Senderismo, escalada, camping y deportes al aire libre",    "mountain"),
            ("Fútbol",              "La pasión argentina: partidos, equipos y jugadores",        "soccer-ball"),
            ("Viajes",              "Destinos, tips de viaje y experiencias alrededor del mundo","plane"),
            ("Gastronomía",         "Recetas, restaurantes, cocina internacional y foodie",      "utensils"),
            ("Café y Barismo",      "Cultura del café, métodos de preparación y variedades",    "coffee"),
            ("Vinos y Bodegas",     "Enología, catas, regiones vitivinícolas y maridajes",      "wine-glass"),
            ("Ciencia",             "Física, química, biología y divulgación científica",        "flask"),
            ("Astronomía",          "Cosmos, telescopios, misiones espaciales y astrofísica",    "star"),
            ("Medio Ambiente",      "Ecología, cambio climático y sustentabilidad",              "leaf"),
            ("Historia",            "Historia universal, argentina y arqueología",               "landmark"),
            ("Filosofía",           "Pensamiento crítico, ética y grandes preguntas",            "brain"),
            ("Educación",           "Pedagogía, recursos didácticos y aprendizaje continuo",    "graduation-cap"),
            ("Emprendimiento",      "Startups, modelos de negocio e innovación",                 "rocket"),
            ("Marketing Digital",   "SEO, redes sociales, contenido y publicidad online",       "megaphone"),
            ("Finanzas Personales", "Ahorro, inversión, criptomonedas y educación financiera",  "dollar-sign"),
            ("Diseño UX/UI",        "Experiencia de usuario, interfaces y prototipado",          "layout"),
            ("Mascotas",            "Perros, gatos, cuidado animal y adopción responsable",     "paw"),
            ("Jardinería",          "Plantas de interior, huerta urbana y paisajismo",           "sprout"),
            ("DIY y Manualidades",  "Hazlo tú mismo, crafts, woodworking y upcycling",          "scissors"),
            ("Coleccionismo",       "Figuras, monedas, cartas y objetos de colección",          "archive"),
        ]
        lineas = []
        for nombre, desc, icono in categorias:
            nombre_esc = nombre.replace("'", "''")
            desc_esc = desc.replace("'", "''")
            lineas.append(f"('{nombre_esc}', '{desc_esc}', '{icono}')")
        f.write(",\n".join(lineas) + ";\n\n")

        # ── USUARIOS en bloques de 500 ────────────────────────────────────
        f.write("-- ============================================================\n")
        f.write(f"-- SECCIÓN 2: {len(usuarios):,} USUARIOS ALEATORIOS\n")
        f.write("-- ============================================================\n\n")

        BLOQUE = 500
        for inicio in range(0, len(usuarios), BLOQUE):
            bloque = usuarios[inicio:inicio + BLOQUE]
            f.write("INSERT INTO users (nombre, email, contrasena_hash, bio, fecha_nacimiento) VALUES\n")
            lineas = []
            for nombre, email, hash_, bio, fnac in bloque:
                nombre_esc = nombre.replace("'", "''")
                bio_val = f"'{bio.replace(chr(39), chr(39)*2)}'" if bio else "NULL"
                lineas.append(
                    f"('{nombre_esc}', '{email}', '{hash_}', {bio_val}, '{fnac}')"
                )
            f.write(",\n".join(lineas) + ";\n\n")

        # ── INTERESES en bloques de 1000 ──────────────────────────────────
        f.write("-- ============================================================\n")
        f.write(f"-- SECCIÓN 3: {len(intereses):,} INTERESES ALEATORIOS\n")
        f.write("-- ============================================================\n\n")

        BLOQUE_INT = 1000
        for inicio in range(0, len(intereses), BLOQUE_INT):
            bloque = intereses[inicio:inicio + BLOQUE_INT]
            f.write("INSERT INTO user_interests (user_id, category_id, nivel_interes) VALUES\n")
            lineas = [f"({u}, {c}, {n})" for u, c, n in bloque]
            f.write(",\n".join(lineas) + ";\n\n")

        f.write("-- Fin del seed masivo\n")

    print(f"✅ Archivo generado: {path}")
    print(f"   Usuarios:  {len(usuarios):,}")
    print(f"   Intereses: {len(intereses):,}")

# ── MAIN ──────────────────────────────────────────────────────────────────────
print("⏳ Generando datos...")
usuarios  = generar_usuarios(TOTAL_USUARIOS)
intereses = generar_intereses(TOTAL_USUARIOS, TOTAL_CATEGORIAS)
import os
# Guarda el SQL en la carpeta correcta relativa al script
output_path = os.path.join(os.path.dirname(__file__), "..", "db", "postgres_init", "02_seed_data.sql")
output_path = os.path.normpath(output_path)
escribir_sql(usuarios, intereses, output_path)