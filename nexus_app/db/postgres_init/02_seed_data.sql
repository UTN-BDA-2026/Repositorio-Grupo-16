-- ============================================================
--  1. Categorías principales (grandes temas)
--  2. Subcategorías/etiquetas (temas específicos)
--  3. Usuarios de prueba
--  4. Intereses de prueba (relación usuario-categoría)
-- ============================================================

-- ============================================================
-- SECCIÓN 1: CATEGORÍAS PRINCIPALES: Son los grandes temas de interés de la red social.
-- El campo "icono" usa nombres de íconos estándar (ej: FontAwesome)
-- ============================================================

INSERT INTO categories (nombre, descripcion, icono) VALUES

-- 🖥️ Tecnología
('Tecnología',        'Todo sobre software, hardware y tendencias tech',         'laptop'),
('Inteligencia Artificial', 'Machine learning, modelos de lenguaje y automatización', 'robot'),
('Programación',      'Lenguajes, frameworks y buenas prácticas de código',      'code'),
('Ciberseguridad',    'Seguridad informática, hacking ético y privacidad',       'shield'),
('Videojuegos',       'Gaming, desarrollo de juegos y cultura gamer',            'gamepad'),

-- 🎨 Arte y Cultura
('Arte Digital',      'Ilustración, diseño gráfico y arte generado por IA',     'palette'),
('Fotografía',        'Técnicas, equipos y edición fotográfica',                 'camera'),
('Música',            'Géneros musicales, producción y artistas',                'music'),
('Cine y Series',     'Películas, series, análisis y recomendaciones',           'film'),
('Literatura',        'Libros, autores, géneros y clubes de lectura',            'book'),
('Animación',         'Anime, cartoons, motion graphics y stop motion',          'tv'),
('Moda',              'Tendencias, diseño de indumentaria y estilo personal',    'shirt'),

-- 🏃 Deportes y Bienestar
('Deportes',          'Fútbol, básquet, tenis y deportes en general',            'trophy'),
('Fitness',           'Entrenamiento, gimnasio, rutinas y nutrición deportiva',  'dumbbell'),
('Yoga y Meditación', 'Mindfulness, bienestar mental y práctica espiritual',    'heart'),
('Outdoor',           'Senderismo, escalada, camping y deportes al aire libre',  'mountain'),
('Fútbol',            'La pasión argentina: partidos, equipos y jugadores',      'soccer-ball'),

-- 🌍 Viajes y Gastronomía
('Viajes',            'Destinos, tips de viaje y experiencias alrededor del mundo', 'plane'),
('Gastronomía',       'Recetas, restaurantes, cocina internacional y foodie',    'utensils'),
('Café y Barismo',    'Cultura del café, métodos de preparación y variedades',   'coffee'),
('Vinos y Bodegas',   'Enología, catas, regiones vitivinícolas y maridajes',    'wine-glass'),

-- 🔬 Ciencia y Educación
('Ciencia',           'Física, química, biología y divulgación científica',      'flask'),
('Astronomía',        'Cosmos, telescopios, misiones espaciales y astrofísica',  'star'),
('Medio Ambiente',    'Ecología, cambio climático y sustentabilidad',            'leaf'),
('Historia',          'Historia universal, argentina y arqueología',             'landmark'),
('Filosofía',         'Pensamiento crítico, ética y grandes preguntas',          'brain'),
('Educación',         'Pedagogía, recursos didácticos y aprendizaje continuo',  'graduation-cap'),

-- 💼 Negocios y Emprendimiento
('Emprendimiento',    'Startups, modelos de negocio e innovación',               'rocket'),
('Marketing Digital', 'SEO, redes sociales, contenido y publicidad online',     'megaphone'),
('Finanzas Personales','Ahorro, inversión, criptomonedas y educación financiera','dollar-sign'),
('Diseño UX/UI',      'Experiencia de usuario, interfaces y prototipado',        'layout'),

-- 🐾 Lifestyle y Hobbies
('Mascotas',          'Perros, gatos, cuidado animal y adopción responsable',   'paw'),
('Jardinería',        'Plantas de interior, huerta urbana y paisajismo',         'sprout'),
('DIY y Manualidades','Hazlo tú mismo, crafts, woodworking y upcycling',        'scissors'),
('Coleccionismo',     'Figuras, monedas, cartas y objetos de colección',        'archive'),
('Astrología',        'Signos del zodíaco, cartas natales y horóscopo',         'moon');

-- ============================================================
-- SECCIÓN 2: USUARIOS DE PRUEBA
-- Se usan para testear el algoritmo de recomendación.
-- Las contraseñas son hashes bcrypt de "password123"
-- NUNCA usar contraseñas reales en seeds.
-- ============================================================

INSERT INTO users (nombre, email, contrasena_hash, bio) VALUES
('Lucía Martínez',   'lucia@example.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Desarrolladora web apasionada por el café ☕ y el open source'),
('Mateo González',   'mateo@example.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Gamer y fan del anime. Siempre buscando el próximo RPG épico 🎮'),
('Valentina López',  'vale@example.com',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Fotógrafa freelance. La vida es mejor con buena luz 📷'),
('Nicolás Herrera',  'nico@example.com',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Ingeniero en sistemas, runner amateur y sommelier en formación 🍷'),
('Sofía Ramírez',    'sofi@example.com',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Emprendedora, mamá de dos gatos y fan del yoga 🧘'),
('Diego Fernández',  'diego@example.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Data scientist de día, músico de noche 🎸'),
('Camila Torres',    'cami@example.com',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Viajera empedernida. 30 países y contando ✈️'),
('Sebastián Ruiz',   'sebas@example.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Amante del fútbol, la historia y las series de crimen 🔍'),
('Florencia Díaz',   'flor@example.com',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Diseñadora UX apasionada por la accesibilidad web 🎨'),
('Tomás Acosta',     'tomas@example.com',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJobMEV.G3v8s5L4oBo6kS2i', 'Astrónomo aficionado, filosofo de cafetería y cinéfilo 🌌');

-- ============================================================
-- SECCIÓN 3: INTERESES DE PRUEBA
-- Conecta usuarios con categorías usando la tabla intermedia.
-- nivel_interes: 1 (poco) a 5 (muy apasionado)
--
-- Los IDs de users y categories se asignan en orden de inserción:
-- user_id 1 = Lucía, 2 = Mateo, etc.
-- category_id 1 = Tecnología, 2 = IA, 3 = Programación, etc.
-- ============================================================

INSERT INTO user_interests (user_id, category_id, nivel_interes) VALUES

-- Lucía: tech + café + fotografía
(1, 1, 5),   -- Tecnología ❤️
(1, 3, 5),   -- Programación ❤️
(1, 19, 4),  -- Gastronomía
(1, 20, 5),  -- Café y Barismo ❤️
(1, 7, 3),   -- Fotografía

-- Mateo: gaming + anime + música
(2, 5, 5),   -- Videojuegos ❤️
(2, 11, 5),  -- Animación (anime) ❤️
(2, 8, 4),   -- Música
(2, 2, 3),   -- Inteligencia Artificial
(2, 9, 3),   -- Cine y Series

-- Valentina: fotografía + viajes + arte
(3, 7, 5),   -- Fotografía ❤️
(3, 18, 5),  -- Viajes ❤️
(3, 6, 4),   -- Arte Digital
(3, 19, 4),  -- Gastronomía
(3, 12, 3),  -- Moda

-- Nicolás: tech + vinos + running
(4, 1, 4),   -- Tecnología
(4, 4, 4),   -- Ciberseguridad
(4, 21, 5),  -- Vinos y Bodegas ❤️
(4, 14, 4),  -- Fitness
(4, 18, 3),  -- Viajes

-- Sofía: emprendimiento + yoga + mascotas
(5, 27, 5),  -- Emprendimiento ❤️
(5, 28, 4),  -- Marketing Digital
(5, 15, 5),  -- Yoga y Meditación ❤️
(5, 33, 5),  -- Mascotas ❤️
(5, 29, 3),  -- Finanzas Personales

-- Diego: música + data/IA + fitness
(6, 8, 5),   -- Música ❤️
(6, 2, 5),   -- Inteligencia Artificial ❤️
(6, 3, 4),   -- Programación
(6, 14, 4),  -- Fitness
(6, 22, 3),  -- Ciencia

-- Camila: viajes + gastronomía + idiomas/cultura
(7, 18, 5),  -- Viajes ❤️
(7, 19, 5),  -- Gastronomía ❤️
(7, 20, 4),  -- Café y Barismo
(7, 25, 3),  -- Historia
(7, 12, 3),  -- Moda

-- Sebastián: fútbol + historia + series
(8, 17, 5),  -- Fútbol ❤️
(8, 13, 4),  -- Deportes
(8, 25, 5),  -- Historia ❤️
(8, 9, 4),   -- Cine y Series
(8, 26, 3),  -- Filosofía

-- Florencia: diseño + arte + tecnología
(9, 30, 5),  -- Diseño UX/UI ❤️
(9, 6, 5),   -- Arte Digital ❤️
(9, 1, 3),   -- Tecnología
(9, 12, 4),  -- Moda
(9, 7, 4),   -- Fotografía

-- Tomás: astronomía + filosofía + cine
(10, 23, 5), -- Astronomía ❤️
(10, 26, 5), -- Filosofía ❤️
(10, 9, 4),  -- Cine y Series
(10, 22, 4), -- Ciencia
(10, 10, 3); -- Literatura