--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categorias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categorias (
    id_categoria integer NOT NULL,
    nombre_categoria character varying(100) NOT NULL
);


ALTER TABLE public.categorias OWNER TO postgres;

--
-- Name: categorias_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categorias_id_categoria_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categorias_id_categoria_seq OWNER TO postgres;

--
-- Name: categorias_id_categoria_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categorias_id_categoria_seq OWNED BY public.categorias.id_categoria;


--
-- Name: etiquetas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.etiquetas (
    id_etiqueta integer NOT NULL,
    id_categoria integer NOT NULL,
    nombre_etiqueta character varying(100) NOT NULL
);


ALTER TABLE public.etiquetas OWNER TO postgres;

--
-- Name: etiquetas_id_etiqueta_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.etiquetas_id_etiqueta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.etiquetas_id_etiqueta_seq OWNER TO postgres;

--
-- Name: etiquetas_id_etiqueta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.etiquetas_id_etiqueta_seq OWNED BY public.etiquetas.id_etiqueta;


--
-- Name: fotos_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fotos_usuario (
    id_foto integer NOT NULL,
    id_usuario integer NOT NULL,
    foto_url text NOT NULL,
    descripcion character varying(255),
    fecha_subida timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.fotos_usuario OWNER TO postgres;

--
-- Name: fotos_usuario_id_foto_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fotos_usuario_id_foto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fotos_usuario_id_foto_seq OWNER TO postgres;

--
-- Name: fotos_usuario_id_foto_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fotos_usuario_id_foto_seq OWNED BY public.fotos_usuario.id_foto;


--
-- Name: usuario_etiquetas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_etiquetas (
    id_usuario integer NOT NULL,
    id_etiqueta integer NOT NULL,
    fecha_agregado timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.usuario_etiquetas OWNER TO postgres;

--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash text NOT NULL,
    fecha_nacimiento date NOT NULL,
    sexo character varying(20) NOT NULL,
    foto_perfil_url text,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_mayor_edad CHECK ((age((fecha_nacimiento)::timestamp with time zone) >= '18 years'::interval)),
    CONSTRAINT check_sexo CHECK (((sexo)::text = ANY ((ARRAY['Femenino'::character varying, 'Masculino'::character varying, 'Otro'::character varying])::text[])))
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_id_usuario_seq OWNER TO postgres;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_usuario_seq OWNED BY public.usuarios.id_usuario;


--
-- Name: categorias id_categoria; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias ALTER COLUMN id_categoria SET DEFAULT nextval('public.categorias_id_categoria_seq'::regclass);


--
-- Name: etiquetas id_etiqueta; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.etiquetas ALTER COLUMN id_etiqueta SET DEFAULT nextval('public.etiquetas_id_etiqueta_seq'::regclass);


--
-- Name: fotos_usuario id_foto; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fotos_usuario ALTER COLUMN id_foto SET DEFAULT nextval('public.fotos_usuario_id_foto_seq'::regclass);


--
-- Name: usuarios id_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuarios_id_usuario_seq'::regclass);


--
-- Data for Name: categorias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categorias (id_categoria, nombre_categoria) FROM stdin;
1	Vida Activa y Aire Libre
2	Gastronom¡a y Salidas Social
3	Creatividad y Cultura
4	Tecnolog¡a y Ocio Digital
5	Estilo de Vida y Valores
6	M£sica: G‚neros y Estilos
\.


--
-- Data for Name: etiquetas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.etiquetas (id_etiqueta, id_categoria, nombre_etiqueta) FROM stdin;
1	1	Senderismo
2	1	Trekking
3	1	Entrenamiento
4	1	Gimnasio
5	1	Deportes
6	1	Yoga
7	1	Meditaci¢n
8	1	Ciclismo
9	1	Running
10	2	Caf‚
11	2	Cerveza
12	2	Cocina
13	2	Pasteler¡a
14	2	Vinos
15	2	Restaurantes
16	2	Asado
17	2	Coctel
18	3	Series
19	3	Pel¡culas
20	3	Recitales
21	3	Fotograf¡a
22	3	Lectura
23	3	Pintura
24	3	M£sica en Vivo
25	3	Cer mica
26	3	Confecci¢n de Indumentaria
27	4	Videojuegos
28	4	Mortal Kombat
29	4	League of Legends
30	4	Fortnite
31	4	Clash Royale
32	4	Tecnolog¡a
33	4	Computaci¢n
34	4	PC
35	4	PlayStation
36	4	Celular
37	4	Xbox
38	5	Viajar
39	5	Mochilero
40	5	Mascotas
41	5	Perro
42	5	Gato
43	5	Conejo
44	5	Ecolog¡a
45	5	Voluntariado
46	5	Sustentabilidad
47	6	Rock
48	6	Rock Alternativo
49	6	Rock Indie
50	6	Heavy Metal
51	6	Electr¢nica
52	6	Techno
53	6	Brazilian Phonk
54	6	Trap
55	6	Reggaet¢n
56	6	Urbano
57	6	Jazz
58	6	Blues
59	6	Pop
60	6	K-Pop
61	6	Cl sica
62	6	Instrumental
63	6	Coleccionismo
64	6	Discos/Vinilos
65	6	DJ
66	6	Productor
67	6	Karaoke
68	6	Lo-fi
69	6	Chillhop
\.


--
-- Data for Name: fotos_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fotos_usuario (id_foto, id_usuario, foto_url, descripcion, fecha_subida) FROM stdin;
\.


--
-- Data for Name: usuario_etiquetas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuario_etiquetas (id_usuario, id_etiqueta, fecha_agregado) FROM stdin;
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id_usuario, username, email, password_hash, fecha_nacimiento, sexo, foto_perfil_url, fecha_registro) FROM stdin;
\.


--
-- Name: categorias_id_categoria_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categorias_id_categoria_seq', 6, true);


--
-- Name: etiquetas_id_etiqueta_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.etiquetas_id_etiqueta_seq', 69, true);


--
-- Name: fotos_usuario_id_foto_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fotos_usuario_id_foto_seq', 1, false);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 1, false);


--
-- Name: categorias categorias_nombre_categoria_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_categoria_key UNIQUE (nombre_categoria);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id_categoria);


--
-- Name: etiquetas etiquetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.etiquetas
    ADD CONSTRAINT etiquetas_pkey PRIMARY KEY (id_etiqueta);


--
-- Name: fotos_usuario fotos_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fotos_usuario
    ADD CONSTRAINT fotos_usuario_pkey PRIMARY KEY (id_foto);


--
-- Name: etiquetas unique_etiqueta_categoria; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.etiquetas
    ADD CONSTRAINT unique_etiqueta_categoria UNIQUE (id_categoria, nombre_etiqueta);


--
-- Name: usuario_etiquetas usuario_etiquetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_etiquetas
    ADD CONSTRAINT usuario_etiquetas_pkey PRIMARY KEY (id_usuario, id_etiqueta);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: usuarios usuarios_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_username_key UNIQUE (username);


--
-- Name: etiquetas fk_categoria; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.etiquetas
    ADD CONSTRAINT fk_categoria FOREIGN KEY (id_categoria) REFERENCES public.categorias(id_categoria) ON DELETE CASCADE;


--
-- Name: fotos_usuario fk_usuario_fotos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fotos_usuario
    ADD CONSTRAINT fk_usuario_fotos FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: usuario_etiquetas usuario_etiquetas_id_etiqueta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_etiquetas
    ADD CONSTRAINT usuario_etiquetas_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES public.etiquetas(id_etiqueta) ON DELETE CASCADE;


--
-- Name: usuario_etiquetas usuario_etiquetas_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_etiquetas
    ADD CONSTRAINT usuario_etiquetas_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

