#!/bin/bash

set -e

VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"
VAULT_PATH="${VAULT_PATH:-secret/data/demo-app}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/secrets.env}"

if [ -z "${VAULT_TOKEN}" ]; then
    echo "ERROR: VAULT_TOKEN no está configurado"
    exit 1
fi

echo "Obteniendo secretos de Vault..."
echo "Vault Address: ${VAULT_ADDR}"
echo "Vault Path: ${VAULT_PATH}"

# Obtener secretos usando curl
SECRETS_JSON=$(curl -s \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/${VAULT_PATH}")

# Verificar si la respuesta es válida
if echo "$SECRETS_JSON" | jq -e '.data.data' > /dev/null 2>&1; then
    # Extraer los datos del formato KV v2 y crear archivo .env
    echo "$SECRETS_JSON" | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"' > "${OUTPUT_FILE}"
    
    echo "Secretos obtenidos correctamente en ${OUTPUT_FILE}:"
    cat "${OUTPUT_FILE}" | sed 's/=.*/=***/' | head -5
    echo "..."
    echo "Total de secretos: $(wc -l < ${OUTPUT_FILE})"
else
    echo "ERROR: No se pudieron obtener los secretos de Vault"
    echo "Respuesta: $SECRETS_JSON"
    exit 1
fi
