// Create unique constraints on User nodes
CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:Usuario) REQUIRE u.id IS UNIQUE;

CREATE CONSTRAINT user_email_unique IF NOT EXISTS
FOR (u:Usuario) REQUIRE u.email IS UNIQUE;

// Create unique constraint on Tag nodes
CREATE CONSTRAINT tag_name_unique IF NOT EXISTS
FOR (t:Etiqueta) REQUIRE t.nombre IS UNIQUE;

// Create indexes for better query performance
CREATE INDEX user_email_index IF NOT EXISTS
FOR (u:Usuario) ON (u.email);

CREATE INDEX user_created_at_index IF NOT EXISTS
FOR (u:Usuario) ON (u.created_at);

CREATE INDEX tag_nombre_index IF NOT EXISTS
FOR (t:Etiqueta) ON (t.nombre);

// Create composite indexes for common queries
CREATE INDEX usuario_interes_index IF NOT EXISTS
FOR ()-[r:INTERESADO_EN]->(t:Etiqueta) ON (r.created_at);
