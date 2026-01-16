#!/bin/bash

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

NAMESPACE="demo-app"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Verificando despliegue de demo-app${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Verificar namespace
echo -e "${YELLOW}1. Verificando namespace...${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' existe${NC}"
else
    echo -e "${RED}✗ Namespace '$NAMESPACE' no existe${NC}"
    exit 1
fi

# Verificar secret
echo -e "${YELLOW}2. Verificando Secret...${NC}"
if kubectl get secret demo-app-secret -n $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Secret 'demo-app-secret' existe${NC}"
    SECRET_KEYS=$(kubectl get secret demo-app-secret -n $NAMESPACE -o jsonpath='{.data}' | jq -r 'keys[]' | wc -l)
    echo "  Claves en el secret: $SECRET_KEYS"
else
    echo -e "${RED}✗ Secret 'demo-app-secret' no existe${NC}"
fi

# Verificar deployment
echo -e "${YELLOW}3. Verificando Deployment...${NC}"
if kubectl get deployment demo-app -n $NAMESPACE &> /dev/null; then
    DEPLOYMENT_STATUS=$(kubectl get deployment demo-app -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    READY_REPLICAS=$(kubectl get deployment demo-app -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment demo-app -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$DEPLOYMENT_STATUS" == "True" ] && [ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ]; then
        echo -e "${GREEN}✓ Deployment 'demo-app' está disponible${NC}"
        echo "  Réplicas listas: $READY_REPLICAS/$DESIRED_REPLICAS"
    else
        echo -e "${YELLOW}⚠ Deployment 'demo-app' está desplegando...${NC}"
        echo "  Réplicas listas: ${READY_REPLICAS:-0}/$DESIRED_REPLICAS"
    fi
else
    echo -e "${RED}✗ Deployment 'demo-app' no existe${NC}"
fi

# Verificar pods
echo -e "${YELLOW}4. Verificando Pods...${NC}"
PODS=$(kubectl get pods -n $NAMESPACE -l app=demo-app --no-headers 2>/dev/null | wc -l)
if [ "$PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ Encontrados $PODS pod(s)${NC}"
    kubectl get pods -n $NAMESPACE -l app=demo-app
    echo ""
    echo "Estado de los pods:"
    kubectl get pods -n $NAMESPACE -l app=demo-app -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount
else
    echo -e "${RED}✗ No se encontraron pods${NC}"
fi

# Verificar service
echo -e "${YELLOW}5. Verificando Service...${NC}"
if kubectl get service demo-app -n $NAMESPACE &> /dev/null; then
    SERVICE_TYPE=$(kubectl get service demo-app -n $NAMESPACE -o jsonpath='{.spec.type}')
    SERVICE_IP=$(kubectl get service demo-app -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    echo -e "${GREEN}✓ Service 'demo-app' existe${NC}"
    echo "  Tipo: $SERVICE_TYPE"
    echo "  ClusterIP: $SERVICE_IP"
else
    echo -e "${RED}✗ Service 'demo-app' no existe${NC}"
fi

# Verificar HPA
echo -e "${YELLOW}6. Verificando HPA...${NC}"
if kubectl get hpa demo-app-hpa -n $NAMESPACE &> /dev/null; then
    HPA_MIN=$(kubectl get hpa demo-app-hpa -n $NAMESPACE -o jsonpath='{.spec.minReplicas}')
    HPA_MAX=$(kubectl get hpa demo-app-hpa -n $NAMESPACE -o jsonpath='{.spec.maxReplicas}')
    HPA_CURRENT=$(kubectl get hpa demo-app-hpa -n $NAMESPACE -o jsonpath='{.status.currentReplicas}')
    echo -e "${GREEN}✓ HPA 'demo-app-hpa' existe${NC}"
    echo "  Réplicas: $HPA_CURRENT (min: $HPA_MIN, max: $HPA_MAX)"
else
    echo -e "${YELLOW}⚠ HPA 'demo-app-hpa' no existe${NC}"
fi

# Resumen final
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Resumen${NC}"
echo -e "${YELLOW}========================================${NC}"
kubectl get all -n $NAMESPACE

# Verificar salud si el pod está corriendo
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=demo-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$POD_NAME" ]; then
    POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" == "Running" ]; then
        echo ""
        echo -e "${YELLOW}7. Verificando salud de la aplicación...${NC}"
        # Intentar verificar el endpoint de health
        CONTAINER_PORT=$(kubectl get deployment demo-app -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')
        if kubectl exec -n $NAMESPACE $POD_NAME -- curl -s -f http://localhost:$CONTAINER_PORT/health &> /dev/null; then
            echo -e "${GREEN}✓ La aplicación responde en /health${NC}"
        else
            echo -e "${YELLOW}⚠ No se pudo verificar el endpoint /health${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}Verificación completada${NC}"
