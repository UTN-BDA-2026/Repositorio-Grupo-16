// ============================================================
// CONSTRAINTS E ÍNDICES NEO4J — NEXUS
// Alineado con las propiedades reales que crea la API
// Nodo Usuario: {usuario_id, email, nombre_usuario, fecha_creacion}
// Nodo Etiqueta: {etiqueta_id}
// ============================================================

// --- CONSTRAINTS DE UNICIDAD ---

// usuario_id es el identificador que viene de PostgreSQL
CREATE CONSTRAINT user_usuario_id_unique IF NOT EXISTS
FOR (u:Usuario) REQUIRE u.usuario_id IS UNIQUE;

// email también debe ser único en el grafo
CREATE CONSTRAINT user_email_unique IF NOT EXISTS
FOR (u:Usuario) REQUIRE u.email IS UNIQUE;

// etiqueta_id es la propiedad real con la que se hace MATCH al vincular
CREATE CONSTRAINT etiqueta_id_unique IF NOT EXISTS
FOR (t:Etiqueta) REQUIRE t.etiqueta_id IS UNIQUE;

// --- ÍNDICES DE RENDIMIENTO ---

// Búsquedas por email (login, recomendaciones)
CREATE INDEX user_email_index IF NOT EXISTS
FOR (u:Usuario) ON (u.email);

// Búsquedas y ordenamiento por fecha de creación del usuario
CREATE INDEX user_fecha_creacion_index IF NOT EXISTS
FOR (u:Usuario) ON (u.fecha_creacion);

// --- ÍNDICE COMPUESTO EN RELACIÓN ---

// Ordenar/filtrar relaciones INTERESADO_EN por fecha
CREATE INDEX usuario_interes_index IF NOT EXISTS
FOR ()-[r:INTERESADO_EN]->(t:Etiqueta) ON (r.fecha_creacion);