# Reporte de Auditoría: Operaciones, WAL y Seguridad
**Responsable:** Emiliano Rossi

## 1. Auditoría de Seguridad (Prevención de SQL Injection)
Se realizó una revisión exhaustiva del código en la capa de modelos (`app/models/relational.py`) y en los esquemas de entrada. 
**Veredicto: Seguro.**
- **Mitigación ORM:** No existen consultas SQL crudas. Se utiliza el ORM de SQLAlchemy, el cual parametriza internamente todas las consultas, separando la lógica del código de los datos del usuario.
- **Validación de Entrada:** Se verificó el uso de la librería Pydantic (`EmailStr`) en los requests, lo que actúa como primera barrera rechazando strings maliciosos antes de que lleguen a la base de datos.

## 2. Resiliencia y Recuperabilidad (WAL)
Se validó la estrategia de tolerancia a fallos frente a las transacciones híbridas (PostgreSQL + Neo4j).
La durabilidad (Propiedad ACID) de los `commits` realizados en el backend está garantizada por el mecanismo de **Write-Ahead Logging (WAL)** de PostgreSQL.
- Las transacciones se registran secuencialmente en la bitácora (WAL) antes de aplicarse a los archivos de datos principales.
- En caso de una caída abrupta del contenedor tras un `commit`, el sistema ejecutará automáticamente un **Crash Recovery** al reiniciar, leyendo el WAL y aplicando las operaciones faltantes mediante un proceso de *Redo*, evitando cualquier tipo de corrupción de datos.