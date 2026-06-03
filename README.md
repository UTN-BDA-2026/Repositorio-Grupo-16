# Repositorio-Grupo-16
Integrantes: Bettiol, Giuliana - Martínez Oldani, Jimena - Rossi, Emiliano - Ruiz Andeola, Alejandro - Sanchez, Juan Ignacio
 
 Contexto de "Nexus":
 -una plataforma social diseñada para conectar personas basándose en la afinidad de sus intereses y hobbies.

Arquitectura de Datos:
-PostgreSQL:  gestionando los perfiles de usuario, autenticación, galería de fotos y el diccionario de categorías de interés. 

-Neo4j: Motor de grafos encargado exclusivamente de procesar las interacciones sociales.

## Operaciones, Recuperación y Seguridad

**Responsable:** Emiliano Rossi

### 1. Seguridad: Auditoría y Prevención de SQL Injection
Se realizó una auditoría exhaustiva en la capa de acceso a datos (`app/services/user_service.py` y `app/models/relational.py`) para garantizar la invulnerabilidad ante ataques de Inyección SQL.
* **Implementación Segura:** Todas las inserciones y búsquedas utilizan el driver `psycopg2` mediante **consultas parametrizadas**. 
* **Mecanismo de Defensa:** El código evita por completo la concatenación de strings (`f"..."` o `+`). Al utilizar el comodín `%s`, se delega el escapado de caracteres al driver en C. PostgreSQL compila el plan de ejecución de la consulta primero y, posteriormente, inserta las variables del usuario tratándolas estrictamente como literales de texto, aislando cualquier código malicioso.

### 2. Recuperación de Datos y Transacciones (WAL)
En conjunto con la orquestación de transacciones híbridas, el sistema garantiza la **Durabilidad** (ACID) de los datos en PostgreSQL frente a caídas del sistema mediante el uso de **Write-Ahead Logging (WAL)**.
* **Funcionamiento:** Para evitar cuellos de botella por escrituras aleatorias en disco, PostgreSQL registra cada cambio de estado secuencialmente en el archivo WAL *antes* de aplicarlo a los archivos de datos principales.
* **Crash Recovery:** Si el contenedor `nexus-postgres` sufre un fallo eléctrico o es interrumpido abruptamente durante una transacción con Neo4j, la base de datos no se corrompe. Al reiniciar, PostgreSQL lee el WAL: ejecuta un **Redo** sobre las transacciones que llegaron a hacer `COMMIT` pero no se volcaron a las tablas, y descarta (rollback implícito) las operaciones incompletas, manteniendo sincronía con la lógica del backend.
