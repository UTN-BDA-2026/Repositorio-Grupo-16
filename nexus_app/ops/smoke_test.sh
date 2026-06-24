API_URL="http://localhost:8000"
USERNAME="juana.carrizo85@example.com"
PASSWORD="secret"

echo "=========================================="
echo "Iniciando Smoke Test para Nexus API..."
echo "=========================================="

# 1. Verificar estado de la API (GET /health)
echo -e "\n[1/3] Llamando a GET /health..."
HEALTH_RES=$(curl -s "$API_URL/health")

if [ -z "$HEALTH_RES" ]; then
    echo "Error: La API no responde en $API_URL. ¿Está levantado el servidor?"
    exit 1
fi
echo "Respuesta: $HEALTH_RES"


# 2. Hacer Login (POST /login)
echo -e "\n[2/3] Autenticando usuario (POST /login)..."
LOGIN_RES=$(curl -s -X POST "$API_URL/login" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=$USERNAME&password=$PASSWORD")

TOKEN=$(echo "$LOGIN_RES" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "Error: Falló el login o no se pudo extraer el access_token."
    echo "Respuesta cruda del servidor: $LOGIN_RES"
    exit 1
fi
echo "Token extraído correctamente (***...***)"


# 3. Validar token (GET /me)
echo -e "\n[3/3] Consultando perfil con token (GET /me)..."
ME_RES=$(curl -s -X GET "$API_URL/me" \
     -H "Authorization: Bearer $TOKEN")

# Verificamos si la respuesta contiene un error de FastAPI (suele devolver {"detail": ...})
if echo "$ME_RES" | grep -q '"detail":'; then
     echo "Error: El endpoint rechazó el token."
     echo "Respuesta cruda del servidor: $ME_RES"
     exit 1
fi
echo "Respuesta: $ME_RES"

# Resultado final
echo -e "\n=========================================="
echo "✓ Smoke test OK"
echo "=========================================="