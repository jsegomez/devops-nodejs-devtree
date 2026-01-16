# DevOps Node.js DevTree - Jenkins + Vault + Kubernetes

Proyecto para desplegar una aplicación Node.js a Kubernetes usando Jenkins y gestionando secretos con Vault.

## Arquitectura

Este proyecto implementa un pipeline CI/CD que:
- Usa **Jenkins** para orquestar el despliegue
- Obtiene secretos desde **Vault**
- Despliega la aplicación a **Kubernetes** usando manifiestos YAML

## Estructura del Proyecto

```
devops-nodejs-devtree/
├── demo-app/                    # Manifiestos de la aplicación
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── hpa.yaml
├── infrastructure/
│   ├── vault/                   # Configuración de Vault
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── service-account.yaml
│   └── jenkins/                 # Configuración de Jenkins
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── service-account.yaml
│       └── persistent-volume-claim.yaml
├── jenkins/
│   ├── Jenkinsfile              # Pipeline de Jenkins
│   ├── scripts/
│   │   └── get-vault-secrets.sh
│   └── jobs/
│       └── deploy-demo-app-config.xml
└── scripts/
    └── vault-init.sh            # Script de inicialización de Vault
```

## Requisitos Previos

- Minikube instalado y funcionando
- `kubectl` configurado y conectado al cluster
- `jq` instalado (para procesar JSON)

## Instalación Paso a Paso

### 1. Verificar Minikube

```bash
minikube status
minikube start  # Si no está iniciado
```

### 2. Desplegar Vault

```bash
# Aplicar manifiestos de Vault
kubectl apply -f infrastructure/vault/namespace.yaml
kubectl apply -f infrastructure/vault/service-account.yaml
kubectl apply -f infrastructure/vault/configmap.yaml
kubectl apply -f infrastructure/vault/service.yaml
kubectl apply -f infrastructure/vault/statefulset.yaml

# Esperar a que Vault esté listo
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=120s
```

### 3. Inicializar y Configurar Vault

```bash
# Ejecutar script de inicialización
./scripts/vault-init.sh

# Guardar los tokens que muestra el script
export VAULT_ROOT_TOKEN="[token mostrado]"
export VAULT_JENKINS_TOKEN="[token mostrado]"
```

**Importante**: Guarda estos tokens en un lugar seguro. Los necesitarás para configurar Jenkins.

### 4. Desplegar Jenkins

```bash
# Aplicar manifiestos de Jenkins
kubectl apply -f infrastructure/jenkins/namespace.yaml
kubectl apply -f infrastructure/jenkins/service-account.yaml
kubectl apply -f infrastructure/jenkins/persistent-volume-claim.yaml
kubectl apply -f infrastructure/jenkins/configmap.yaml
kubectl apply -f infrastructure/jenkins/deployment.yaml
kubectl apply -f infrastructure/jenkins/service.yaml

# Esperar a que Jenkins esté listo (puede tardar 2-3 minutos)
kubectl wait --for=condition=ready pod -l app=jenkins -n jenkins --timeout=300s
```

### 5. Acceder a Jenkins

```bash
# Obtener la URL de Jenkins
minikube service jenkins -n jenkins --url

# O usar port-forward
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

Luego accede a: `http://localhost:8080` o `http://[minikube-ip]:30080`

### 6. Configurar Credenciales en Jenkins

1. Accede a Jenkins
2. Ve a **"Manage Jenkins"** > **"Credentials"**
3. Haz clic en **"Add Credentials"**
4. Configura:
   - **Kind**: Secret text
   - **Secret**: `[VAULT_JENKINS_TOKEN del paso 3]`
   - **ID**: `vault-jenkins-token`
   - **Description**: Token de Vault para Jenkins
5. Guarda

### 7. Crear el Job de Jenkins

Sigue las instrucciones en `jenkins/JOB_SETUP.md` o:

1. **New Item** > Nombre: `deploy-demo-app` > **Pipeline** > **OK**
2. En **"Pipeline definition"**: **"Pipeline script from SCM"**
3. **SCM**: Git
4. **Repository URL**: URL de tu repositorio
5. **Script Path**: `jenkins/Jenkinsfile`
6. Guarda

### 8. Ejecutar el Job

1. Haz clic en **"Build Now"** en el Job `deploy-demo-app`
2. Monitorea la ejecución en la consola
3. Verifica el despliegue:

```bash
kubectl get all -n demo-app
```

## Verificación

Usa el script de verificación:

```bash
./scripts/verify-deployment.sh
```

O manualmente:

```bash
# Verificar pods
kubectl get pods -n demo-app

# Ver logs de la aplicación
kubectl logs -n demo-app -l app=demo-app

# Verificar secretos
kubectl get secret demo-app-secret -n demo-app

# Describir deployment
kubectl describe deployment demo-app -n demo-app
```

## Secretos Gestionados

Los siguientes secretos se gestionan en Vault y se inyectan a la aplicación:

- `MONGO_URI`
- `PORT`
- `DATABASE_NAME`
- `ALLOWED_DOMAINS`
- `JWT_SECRET`
- `CLOUDINARY_URL`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

Para actualizar secretos en Vault:

```bash
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- vault kv put secret/demo-app MONGO_URI="nuevo-valor"
```

## Solución de Problemas

### Vault no inicia

```bash
# Ver logs
kubectl logs -n vault -l app=vault

# Verificar estado
kubectl get pods -n vault
```

### Jenkins no puede conectarse a Vault

1. Verifica que Vault esté accesible desde Jenkins:
```bash
kubectl exec -n jenkins -it deployment/jenkins -- curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

2. Verifica que el token de Vault esté configurado correctamente en Jenkins

### El Job falla al obtener secretos

1. Verifica que el token tenga permisos:
```bash
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- vault token lookup
```

2. Verifica que los secretos existan:
```bash
kubectl exec -n vault $VAULT_POD -- vault kv get secret/demo-app
```

### El deployment falla

```bash
# Ver eventos
kubectl get events -n demo-app --sort-by='.lastTimestamp'

# Ver logs del pod
kubectl logs -n demo-app -l app=demo-app

# Describir el deployment
kubectl describe deployment demo-app -n demo-app
```

## Acceso a Vault UI

Para acceder a la interfaz web de Vault:

```bash
kubectl port-forward -n vault svc/vault 8200:8200
```

Luego abre: `http://localhost:8200`

Usa el `VAULT_ROOT_TOKEN` obtenido del script de inicialización.

## Limpieza

Para eliminar todo:

```bash
# Eliminar aplicación
kubectl delete namespace demo-app

# Eliminar Jenkins
kubectl delete namespace jenkins

# Eliminar Vault
kubectl delete namespace vault
```

## Próximos Pasos

Este proyecto implementa el primer Job (despliegue con manifiestos YAML). Los siguientes pasos serían:

1. **Job con Terraform + Kubernetes**: Desplegar usando Terraform con recursos de Kubernetes
2. **Job con Terraform + Helm**: Desplegar usando Terraform con Helm charts

## Referencias

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
