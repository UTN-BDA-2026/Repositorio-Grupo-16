// ============================================================
// DOCUMENTACIÓN DE REFERENCIA — CONSTRAINTS NEO4J
// ============================================================
// NOTA: Este archivo NO se ejecuta automáticamente al iniciar.
// Las constraints se aplican mediante ops/sync_neo4j.py o manualmente
// desde Neo4j Browser (http://localhost:7474).
//
// Propiedades reales que usa la API (main.py):
//   Nodo Usuario: { usuario_id, email, nombre_usuario, fecha_creacion }
//   Nodo Etiqueta: { etiqueta_id }
//
// ATENCIÓN: sync_neo4j.py usa propiedades distintas ({ id } y { nombre })
// heredadas de una versión anterior. Pendiente alinear con la API.
// ============================================================

// --- CONSTRAINTS VIGENTES (alineadas con main.py) ---

// CREATE CONSTRAINT user_usuario_id_unique IF NOT EXISTS
// FOR (u:Usuario) REQUIRE u.usuario_id IS UNIQUE;

// CREATE CONSTRAINT user_email_unique IF NOT EXISTS
// FOR (u:Usuario) REQUIRE u.email IS UNIQUE;

// CREATE CONSTRAINT etiqueta_id_unique IF NOT EXISTS
// FOR (t:Etiqueta) REQUIRE t.etiqueta_id IS UNIQUE;

// --- ÍNDICES DE RENDIMIENTO ---

// CREATE INDEX user_email_index IF NOT EXISTS
// FOR (u:Usuario) ON (u.email);

// CREATE INDEX user_fecha_creacion_index IF NOT EXISTS
// FOR (u:Usuario) ON (u.fecha_creacion);
