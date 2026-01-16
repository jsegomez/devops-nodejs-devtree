#!/bin/bash

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Verificación Previa del Entorno${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Verificar kubectl
echo -e "${YELLOW}1. Verificando kubectl...${NC}"
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓ kubectl está instalado${NC}"
    kubectl version --client --short
else
    echo -e "${RED}✗ kubectl no está instalado${NC}"
    exit 1
fi

# Verificar conexión al cluster
echo -e "${YELLOW}2. Verificando conexión al cluster...${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ Conectado al cluster${NC}"
    kubectl cluster-info | head -1
else
    echo -e "${RED}✗ No se puede conectar al cluster${NC}"
    echo "Ejecuta: minikube start"
    exit 1
fi

# Verificar jq
echo -e "${YELLOW}3. Verificando jq...${NC}"
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq está instalado${NC}"
else
    echo -e "${YELLOW}⚠ jq no está instalado (recomendado para los scripts)${NC}"
    echo "Instalar: sudo apt install jq"
fi

# Verificar Vault
echo -e "${YELLOW}4. Verificando Vault...${NC}"
if kubectl get namespace vault &> /dev/null; then
    echo -e "${GREEN}✓ Namespace 'vault' existe${NC}"
    VAULT_PODS=$(kubectl get pods -n vault -l app=vault --no-headers 2>/dev/null | wc -l)
    if [ "$VAULT_PODS" -gt 0 ]; then
        VAULT_STATUS=$(kubectl get pods -n vault -l app=vault -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
        echo "  Estado del pod: $VAULT_STATUS"
        if [ "$VAULT_STATUS" == "Running" ]; then
            echo -e "${GREEN}✓ Vault está corriendo${NC}"
        else
            echo -e "${YELLOW}⚠ Vault está en estado: $VAULT_STATUS${NC}"
        fi
    else
        echo -e "${RED}✗ No se encontraron pods de Vault${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Namespace 'vault' no existe${NC}"
    echo "Ejecuta: kubectl apply -f infrastructure/vault/"
fi

# Verificar Jenkins
echo -e "${YELLOW}5. Verificando Jenkins...${NC}"
if kubectl get namespace jenkins &> /dev/null; then
    echo -e "${GREEN}✓ Namespace 'jenkins' existe${NC}"
    JENKINS_PODS=$(kubectl get pods -n jenkins -l app=jenkins --no-headers 2>/dev/null | wc -l)
    if [ "$JENKINS_PODS" -gt 0 ]; then
        JENKINS_STATUS=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
        echo "  Estado del pod: $JENKINS_STATUS"
        if [ "$JENKINS_STATUS" == "Running" ]; then
            echo -e "${GREEN}✓ Jenkins está corriendo${NC}"
            
            # Obtener URL de Jenkins
            JENKINS_NODEPORT=$(kubectl get svc -n jenkins jenkins -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null || echo "N/A")
            if [ "$JENKINS_NODEPORT" != "N/A" ]; then
                MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
                echo "  URL: http://${MINIKUBE_IP}:${JENKINS_NODEPORT}"
            fi
        else
            echo -e "${YELLOW}⚠ Jenkins está en estado: $JENKINS_STATUS${NC}"
        fi
    else
        echo -e "${RED}✗ No se encontraron pods de Jenkins${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Namespace 'jenkins' no existe${NC}"
    echo "Ejecuta: kubectl apply -f infrastructure/jenkins/"
fi

# Verificar archivos necesarios
echo -e "${YELLOW}6. Verificando archivos necesarios...${NC}"
MISSING_FILES=0

REQUIRED_FILES=(
    "demo-app/namespace.yaml"
    "demo-app/deployment.yaml"
    "demo-app/service.yaml"
    "demo-app/hpa.yaml"
    "jenkins/Jenkinsfile"
    "scripts/vault-init.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file${NC}"
    else
        echo -e "${RED}✗ $file (no encontrado)${NC}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "${RED}✗ Faltan $MISSING_FILES archivos requeridos${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verificación completada${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo "1. Si Vault no está inicializado: ./scripts/vault-init.sh"
echo "2. Si Jenkins no está configurado: Configura las credenciales en Jenkins UI"
echo "3. Crea el Job en Jenkins siguiendo las instrucciones en jenkins/JOB_SETUP.md"
