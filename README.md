# Repositorio-Grupo-16
Integrantes: Bettiol, Giuliana - Martínez Oldani, Jimena - Rossi, Emiliano - Ruiz Andeola, Alejandro - Sanchez, Juan Ignacio
 
 Contexto de "Nexus":
 -una plataforma social diseñada para conectar personas basándose en la afinidad de sus intereses y hobbies.

Arquitectura de Datos:
-PostgreSQL:  gestionando los perfiles de usuario, autenticación, galería de fotos y el diccionario de categorías de interés. 

-Neo4j: Motor de grafos encargado exclusivamente de procesar las interacciones sociales.

Autenticación JWT:
- `POST /login`: endpoint de inicio de sesión que recibe email y password y devuelve un token JWT.
- `GET /me`: endpoint protegido que valida el token Bearer y retorna los datos del usuario autenticado.

La autenticación está implementada en `nexus_app/app/auth.py` y se integra con el resto del proyecto mediante `nexus_app/app/main.py`.