#!/bin/bash

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Esperando a que Vault esté corriendo...${NC}"

# Esperar a que el pod de Vault esté corriendo (no necesariamente ready, porque necesita inicialización)
VAULT_POD=""
for i in {1..30}; do
    VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ ! -z "$VAULT_POD" ]; then
        POD_STATUS=$(kubectl get pod $VAULT_POD -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [ "$POD_STATUS" == "Running" ]; then
            echo -e "${GREEN}Pod de Vault está corriendo${NC}"
            # Esperar un poco más para que Vault termine de iniciar
            sleep 5
            break
        fi
    fi
    echo "Esperando... ($i/30)"
    sleep 2
done

if [ -z "$VAULT_POD" ]; then
    echo -e "${RED}ERROR: No se pudo encontrar el pod de Vault${NC}"
    exit 1
fi

echo -e "${GREEN}Vault pod encontrado: ${VAULT_POD}${NC}"

# Verificar si Vault ya está inicializado
INIT_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.initialized' 2>/dev/null || echo "false")

if [ "$INIT_STATUS" == "true" ]; then
    echo -e "${YELLOW}Vault ya está inicializado${NC}"
    
    # Verificar si está bloqueado
    SEALED_STATUS=$(kubectl exec -n vault $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "true")
    
    if [ "$SEALED_STATUS" == "true" ]; then
        echo -e "${YELLOW}Vault está bloqueado. Necesitas desbloquearlo manualmente${NC}"
        echo "Para desbloquear, necesitas la UNSEAL_KEY original."
        echo "Si no la tienes, puedes reinicializar Vault (esto borrará todos los datos)."
        exit 1
    fi
    
    # Usar root token proporcionado o solicitar
    if [ -z "${VAULT_ROOT_TOKEN}" ]; then
        echo -e "${YELLOW}Vault ya está inicializado. Necesitas proporcionar VAULT_ROOT_TOKEN${NC}"
        echo "export VAULT_ROOT_TOKEN='tu-token' y vuelve a ejecutar el script"
        exit 1
    fi
    ROOT_TOKEN="${VAULT_ROOT_TOKEN}"
    
    # Autenticarse con el token
    kubectl exec -n vault $VAULT_POD -- vault auth $ROOT_TOKEN > /dev/null 2>&1 || echo "Ya autenticado"
else
    echo -e "${YELLOW}Inicializando Vault...${NC}"
    
    # Inicializar Vault
    INIT_OUTPUT=$(kubectl exec -n vault $VAULT_POD -- vault operator init -key-shares=1 -key-threshold=1 -format=json)
    
    UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
    ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')
    
    echo -e "${GREEN}Vault inicializado correctamente${NC}"
    echo -e "${YELLOW}UNSEAL_KEY: ${UNSEAL_KEY}${NC}"
    echo -e "${YELLOW}ROOT_TOKEN: ${ROOT_TOKEN}${NC}"
    
    # Desbloquear Vault
    echo -e "${YELLOW}Desbloqueando Vault...${NC}"
    kubectl exec -n vault $VAULT_POD -- vault operator unseal $UNSEAL_KEY
    
    # Esperar un momento para que Vault se estabilice
    sleep 2
fi

# Configurar política para Jenkins
echo -e "${YELLOW}Configurando políticas de Vault...${NC}"

POLICY_CONTENT='# Política para Jenkins - permisos para leer secretos de demo-app
path "secret/data/demo-app" {
  capabilities = ["read"]
}

path "secret/data/demo-app/*" {
  capabilities = ["read"]
}

path "secret/metadata/demo-app" {
  capabilities = ["list", "read"]
}'

echo "$POLICY_CONTENT" | kubectl exec -i -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$ROOT_TOKEN' && vault policy write jenkins-policy -"

# Habilitar KV secrets engine si no está habilitado
echo -e "${YELLOW}Verificando KV secrets engine...${NC}"
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$ROOT_TOKEN' && vault secrets list | grep -q '^secret/' || vault secrets enable -version=2 -path=secret kv"

# Crear secretos de demo-app en Vault
echo -e "${YELLOW}Creando secretos de demo-app en Vault...${NC}"

# Usar variables de entorno o valores por defecto para desarrollo
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017/demo-app}"
PORT="${PORT:-3000}"
DATABASE_NAME="${DATABASE_NAME:-demo-app}"
ALLOWED_DOMAINS="${ALLOWED_DOMAINS:-http://localhost:3000}"
JWT_SECRET="${JWT_SECRET:-your-secret-jwt-key-change-in-production}"
CLOUDINARY_URL="${CLOUDINARY_URL:-cloudinary://api_key:api_secret@cloud_name}"
CLOUDINARY_CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-demo-cloud}"
CLOUDINARY_API_KEY="${CLOUDINARY_API_KEY:-demo-api-key}"
CLOUDINARY_API_SECRET="${CLOUDINARY_API_SECRET:-demo-api-secret}"

kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$ROOT_TOKEN' && vault kv put secret/demo-app \
  MONGO_URI=\"$MONGO_URI\" \
  PORT=\"$PORT\" \
  DATABASE_NAME=\"$DATABASE_NAME\" \
  ALLOWED_DOMAINS=\"$ALLOWED_DOMAINS\" \
  JWT_SECRET=\"$JWT_SECRET\" \
  CLOUDINARY_URL=\"$CLOUDINARY_URL\" \
  CLOUDINARY_CLOUD_NAME=\"$CLOUDINARY_CLOUD_NAME\" \
  CLOUDINARY_API_KEY=\"$CLOUDINARY_API_KEY\" \
  CLOUDINARY_API_SECRET=\"$CLOUDINARY_API_SECRET\""

# Crear token para Jenkins
echo -e "${YELLOW}Creando token para Jenkins...${NC}"

JENKINS_TOKEN=$(kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$ROOT_TOKEN' && vault token create \
  -policy=jenkins-policy \
  -ttl=8760h \
  -format=json" | jq -r '.auth.client_token')

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Vault configurado correctamente${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}ROOT_TOKEN: ${ROOT_TOKEN}${NC}"
echo -e "${YELLOW}JENKINS_TOKEN: ${JENKINS_TOKEN}${NC}"
echo ""
echo -e "${YELLOW}Guarda estos tokens de forma segura:${NC}"
echo "export VAULT_ROOT_TOKEN=\"${ROOT_TOKEN}\""
echo "export VAULT_JENKINS_TOKEN=\"${JENKINS_TOKEN}\""
echo ""
echo -e "${GREEN}Para acceder a Vault UI, ejecuta:${NC}"
echo "kubectl port-forward -n vault svc/vault 8200:8200"
echo "Luego abre: http://localhost:8200"
