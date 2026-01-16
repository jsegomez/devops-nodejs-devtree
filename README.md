# DevOps Node.js DevTree - Jenkins + Vault + Kubernetes

Proyecto completo de CI/CD que automatiza el despliegue de una aplicación Node.js a Kubernetes usando Jenkins para orquestar el pipeline y Vault para gestionar secretos de forma segura.

## 📋 Tabla de Contenidos

- [Descripción del Proyecto](#-descripción-del-proyecto)
- [Arquitectura](#-arquitectura)
- [Requisitos Previos](#-requisitos-previos)
- [Instalación Completa](#-instalación-completa)
- [Configuración Paso a Paso](#-configuración-paso-a-paso)
- [Verificación del Despliegue](#-verificación-del-despliegue)
- [Gestión de Secretos](#-gestión-de-secretos)
- [Solución de Problemas](#-solución-de-problemas)
- [Estructura del Proyecto](#-estructura-del-proyecto)

## 🎯 Descripción del Proyecto

Este proyecto implementa un pipeline CI/CD completo que:

1. **Obtiene secretos desde Vault** (sistema de gestión de secretos de HashiCorp)
2. **Crea un Secret de Kubernetes** con los valores de Vault
3. **Despliega una aplicación Node.js** a Kubernetes usando manifiestos YAML
4. **Verifica el despliegue** y el estado de los recursos

### Tecnologías Utilizadas

- **Kubernetes** (Minikube): Orquestación de contenedores
- **Jenkins**: Automatización CI/CD
- **HashiCorp Vault**: Gestión de secretos
- **YAML Manifests**: Definición de recursos Kubernetes

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    Minikube Cluster                      │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │    Vault     │         │   Jenkins    │             │
│  │  (StatefulSet)│         │ (Deployment) │             │
│  │              │         │              │             │
│  │ - Almacena   │◄────────┤ - Pipeline   │             │
│  │   secretos   │  Obtiene │ - Obtiene    │             │
│  │              │  secretos│   secretos   │             │
│  └──────────────┘         └──────┬───────┘             │
│                                   │                      │
│                                   │ Crea Secret          │
│                                   │ Aplica Manifiestos   │
│                                   ▼                      │
│                          ┌──────────────┐               │
│                          │  demo-app    │               │
│                          │  Namespace   │               │
│                          │              │               │
│                          │ - Deployment │               │
│                          │ - Service    │               │
│                          │ - HPA        │               │
│                          │ - Secret     │               │
│                          │   (de Vault) │               │
│                          └──────────────┘               │
└─────────────────────────────────────────────────────────┘
```

## 📦 Requisitos Previos

### Software Necesario

1. **Minikube** instalado y funcionando
   ```bash
   # Verificar instalación
   minikube version
   
   # Iniciar Minikube si no está corriendo
   minikube start
   ```

2. **kubectl** configurado
   ```bash
   # Verificar que kubectl funciona
   kubectl version --client
   
   # Verificar conexión al cluster
   kubectl cluster-info
   ```

3. **Git** para clonar el repositorio
   ```bash
   git --version
   ```

4. **jq** para procesar JSON (necesario para los scripts)
   ```bash
   # En Ubuntu/Debian
   sudo apt install -y jq
   
   # Verificar instalación
   jq --version
   ```

### Recursos del Sistema

- **RAM mínima**: 4GB (recomendado 8GB)
- **Espacio en disco**: Al menos 10GB libres
- **CPU**: 2 cores mínimo (recomendado 4 cores)

## 🚀 Instalación Completa

### Paso 1: Clonar el Repositorio

```bash
git clone https://github.com/jsegomez/devops-nodejs-devtree.git
cd devops-nodejs-devtree
```

### Paso 2: Verificar Entorno

Ejecuta el script de verificación previa:

```bash
chmod +x scripts/pre-check.sh
./scripts/pre-check.sh
```

Este script verifica:
- ✅ kubectl instalado y configurado
- ✅ Conexión al cluster de Kubernetes
- ✅ jq instalado
- ✅ Archivos necesarios presentes

### Paso 3: Desplegar Vault

#### 3.1 Crear Namespace y Recursos Base

```bash
cd infrastructure/vault

# Crear namespace
kubectl apply -f namespace.yaml

# Crear ServiceAccount y RBAC
kubectl apply -f service-account.yaml

# Crear ConfigMap con configuración de Vault
kubectl apply -f configmap.yaml

# Crear Service para exponer Vault
kubectl apply -f service.yaml

# Crear StatefulSet para desplegar Vault
kubectl apply -f statefulset.yaml
```

#### 3.2 Verificar que Vault Está Corriendo

```bash
# Esperar a que el pod esté corriendo (puede tardar 30-60 segundos)
kubectl get pods -n vault -w

# Presiona Ctrl+C cuando veas que el pod está en estado "Running"
# Verifica el estado final
kubectl get pods -n vault
```

**Resultado esperado:**
```
NAME      READY   STATUS    RESTARTS   AGE
vault-0   1/1     Running   0          2m
```

Si el pod está en `CrashLoopBackOff` o `Error`, revisa los logs:
```bash
kubectl logs vault-0 -n vault
```

#### 3.3 Inicializar y Configurar Vault

```bash
# Regresar al directorio raíz del proyecto
cd ../..

# Dar permisos de ejecución al script
chmod +x scripts/vault-init.sh

# Ejecutar el script de inicialización
./scripts/vault-init.sh
```

**⚠️ IMPORTANTE**: El script mostrará tokens importantes. **Guárdalos de forma segura**:

```
ROOT_TOKEN: hvs.xxxxxxxxxxxxx
JENKINS_TOKEN: hvs.yyyyyyyyyyyyy
```

**Exporta los tokens** (reemplaza con los valores reales):
```bash
export VAULT_ROOT_TOKEN="hvs.xxxxxxxxxxxxx"
export VAULT_JENKINS_TOKEN="hvs.yyyyyyyyyyyyy"
```

**¿Qué hace el script?**
1. Espera a que Vault esté listo
2. Inicializa Vault (si no está inicializado)
3. Desbloquea Vault
4. Crea política `jenkins-policy` con permisos de lectura
5. Habilita KV secrets engine
6. Crea secretos de demo-app en Vault
7. Genera un token para Jenkins con la política configurada

#### 3.4 Verificar Secretos en Vault (Opcional)

Puedes acceder a la UI de Vault para verificar:

```bash
# Hacer port-forward para acceder desde tu navegador
kubectl port-forward -n vault svc/vault 8200:8200
```

Luego abre en tu navegador: `http://localhost:8200`

**Inicia sesión con:**
- Token: `VAULT_ROOT_TOKEN` (el que guardaste antes)

**Navega a:** Secrets → secret → demo-app

Deberías ver todos los secretos creados.

### Paso 4: Desplegar Jenkins

#### 4.1 Crear Namespace y Recursos Base

```bash
cd infrastructure/jenkins

# Crear namespace
kubectl apply -f namespace.yaml

# Crear ServiceAccount y RBAC (permisos para Jenkins)
kubectl apply -f service-account.yaml

# Crear PersistentVolumeClaim (almacenamiento para Jenkins)
kubectl apply -f persistent-volume-claim.yaml

# Crear ConfigMap con lista de plugins
kubectl apply -f configmap.yaml

# Crear Deployment de Jenkins
kubectl apply -f deployment.yaml

# Crear Service para exponer Jenkins
kubectl apply -f service.yaml
```

#### 4.2 Verificar que Jenkins Está Corriendo

```bash
# Esperar a que Jenkins esté listo (puede tardar 2-3 minutos)
kubectl get pods -n jenkins -w

# Presiona Ctrl+C cuando veas que el pod está en estado "Running"
# Verifica el estado final
kubectl get pods -n jenkins
```

**Resultado esperado:**
```
NAME                     READY   STATUS    RESTARTS   AGE
jenkins-xxxxxxxxx-xxxxx  1/1     Running   0          3m
```

**Nota**: La primera vez que Jenkins inicia, puede tardar varios minutos en instalar los plugins configurados.

#### 4.3 Acceder a Jenkins

**Opción 1: Usando NodePort**
```bash
# Obtener la IP de Minikube
minikube ip

# Jenkins estará disponible en: http://[MINIKUBE_IP]:30080
```

**Opción 2: Usando Port-Forward (Recomendado para WSL)**
```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

Luego abre en tu navegador: `http://localhost:8080`

### Paso 5: Configurar Jenkins

#### 5.1 Instalar Plugins Necesarios

Al acceder a Jenkins por primera vez, ve a:
1. **"Manage Jenkins"** → **"Plugins"**
2. En la pestaña **"Available"**, busca e instala:
   - ✅ **Pipeline** (para pipelines declarativos)
   - ✅ **Git** (para integración con Git)
   - ✅ **Credentials Binding** (para gestionar credenciales)
   - ✅ **Vault Plugin** (opcional, pero útil)

3. Reinicia Jenkins si se solicita

#### 5.2 Configurar Credencial de Vault

1. En Jenkins, ve a **"Manage Jenkins"** → **"Credentials"**
2. Haz clic en **"(global)"** o el dominio que prefieras
3. Haz clic en **"Add Credentials"**
4. Completa el formulario:
   - **Kind**: Secret text
   - **Scope**: Global (o dejarlo por defecto)
   - **Secret**: Pega el `JENKINS_TOKEN` que guardaste en el Paso 3.3
     ```
     hvs.yyyyyyyyyyyyy  # Tu token real
     ```
   - **ID**: `vault-jenkins-token` ⚠️ **Debe ser exactamente este ID**
   - **Description**: "Token de Vault para Jenkins" (opcional)
5. Haz clic en **"OK"**

**Verificación:**
- Deberías ver la credencial listada con el ID `vault-jenkins-token`

#### 5.3 Crear el Job de Jenkins

1. En la página principal de Jenkins, haz clic en **"New Item"** (o "Nuevo elemento")
2. Ingresa el nombre: `deploy-demo-app`
3. Selecciona **"Pipeline"**
4. Haz clic en **"OK"**
5. En la configuración del Job:

   **Pipeline Section:**
   - **Definition**: Selecciona **"Pipeline script from SCM"**
   - **SCM**: Selecciona **"Git"**
   - **Repository URL**: `https://github.com/jsegomez/devops-nodejs-devtree.git`
     (O la URL de tu propio repositorio si hiciste fork)
   - **Credentials**: Deja vacío (es un repositorio público)
   - **Branches to build**: `*/master` (o la rama que uses)
   - **Script Path**: `jenkins/Jenkinsfile`

6. Haz clic en **"Save"**

### Paso 6: Ejecutar el Pipeline

1. En la página del Job `deploy-demo-app`, haz clic en **"Build Now"** (o "Ejecutar ahora")
2. Verás un nuevo build aparecer en **"Build History"**
3. Haz clic en el número del build (#1) para ver los detalles
4. Haz clic en **"Console Output"** para ver los logs en tiempo real

**El pipeline ejecutará estos stages:**
1. ✅ **Preparar entorno** - Instala kubectl y jq si no están disponibles
2. ✅ **Obtener secretos de Vault** - Se conecta a Vault y obtiene los secretos
3. ✅ **Crear Secret de Kubernetes** - Crea el Secret con los valores de Vault
4. ✅ **Desplegar manifiestos** - Aplica namespace, deployment, service, hpa
5. ✅ **Verificar despliegue** - Verifica que todo esté funcionando

**Tiempo estimado:** 2-3 minutos

## ✅ Verificación del Despliegue

### Verificación Rápida

```bash
# Ver todos los recursos desplegados
kubectl get all -n demo-app
```

**Resultado esperado:**
```
NAME                            READY   STATUS    RESTARTS   AGE
pod/demo-app-xxxxxxxxx-xxxxx    1/1     Running   0          2m

NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/demo-app   ClusterIP   10.xx.xx.xx    <none>        80/TCP    2m

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/demo-app   1/1     1            1           2m

NAME                                               REFERENCE             TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/demo-app-hpa   Deployment/demo-app   <unknown> 1         5         1          2m
```

### Verificación Detallada

Ejecuta el script de verificación:

```bash
chmod +x scripts/verify-deployment.sh
./scripts/verify-deployment.sh
```

Este script verifica:
- ✅ Namespace existe
- ✅ Secret creado
- ✅ Deployment disponible
- ✅ Pods corriendo
- ✅ Service creado
- ✅ HPA configurado

### Verificación Manual

```bash
# Ver estado de los pods
kubectl get pods -n demo-app -o wide

# Ver logs de la aplicación
kubectl logs -n demo-app -l app=demo-app --tail=50

# Verificar que el Secret tiene los valores correctos
kubectl get secret demo-app-secret -n demo-app

# Ver detalles del deployment
kubectl describe deployment demo-app -n demo-app

# Verificar variables de entorno en el pod
kubectl describe pod -n demo-app -l app=demo-app | grep -A 10 "Environment:"
```

**Logs esperados de la aplicación:**
```
🚀 Servidor corriendo en puerto 5000
📝 Entorno: production
🟢 Database connected
```

## 🔐 Gestión de Secretos

### Ver Secretos en Vault

**Opción 1: Desde la UI de Vault**
```bash
kubectl port-forward -n vault svc/vault 8200:8200
```
Luego: `http://localhost:8200` → Secrets → secret → demo-app

**Opción 2: Desde la terminal**
```bash
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$VAULT_ROOT_TOKEN' && vault kv get secret/demo-app"
```

### Actualizar un Secreto en Vault

**Opción 1: Desde la UI de Vault**
1. Accede a la UI de Vault
2. Ve a: Secrets → secret → demo-app
3. Haz clic en **"Create new version"**
4. Modifica el valor deseado
5. Guarda

**Opción 2: Desde la terminal**
```bash
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$VAULT_ROOT_TOKEN' && vault kv put secret/demo-app MONGO_URI='nuevo-valor'"
```

**⚠️ Importante**: Después de actualizar secretos en Vault, debes:
1. Ejecutar el pipeline nuevamente en Jenkins
2. O actualizar el Secret de Kubernetes manualmente:
   ```bash
   # El pipeline recreará el Secret con los nuevos valores
   ```

### Agregar un Nuevo Secreto

```bash
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$VAULT_ROOT_TOKEN' && vault kv put secret/demo-app NEW_SECRET='valor'"
```

Luego actualiza el `deployment.yaml` para usar el nuevo secreto y ejecuta el pipeline.

### Secretos Gestionados Actualmente

El proyecto gestiona estos secretos en Vault:
- `MONGO_URI` - URI de conexión a MongoDB
- `PORT` - Puerto de la aplicación
- `DATABASE_NAME` - Nombre de la base de datos
- `ALLOWED_DOMAINS` - Dominios permitidos (CORS)
- `JWT_SECRET` - Secreto para JWT tokens
- `CLOUDINARY_URL` - URL de Cloudinary
- `CLOUDINARY_CLOUD_NAME` - Nombre de la nube en Cloudinary
- `CLOUDINARY_API_KEY` - API Key de Cloudinary
- `CLOUDINARY_API_SECRET` - API Secret de Cloudinary

## 🔧 Solución de Problemas

### Vault no inicia

**Síntomas:** Pod en `CrashLoopBackOff` o `Error`

**Solución:**
```bash
# Ver logs detallados
kubectl logs vault-0 -n vault --tail=50

# Verificar estado del pod
kubectl describe pod vault-0 -n vault

# Revisar eventos
kubectl get events -n vault --sort-by='.lastTimestamp'
```

**Causas comunes:**
- Problemas de permisos (revisa el StatefulSet)
- PVC no disponible (verifica con `kubectl get pvc -n vault`)
- Configuración incorrecta en ConfigMap

### Jenkins no puede conectarse a Vault

**Síntomas:** El pipeline falla en el stage "Obtener secretos de Vault"

**Solución:**
```bash
# Verificar conectividad desde Jenkins
kubectl exec -n jenkins deployment/jenkins -- curl -s http://vault.vault.svc.cluster.local:8200/v1/sys/health

# Verificar que el token esté configurado correctamente
# En Jenkins: Manage Jenkins → Credentials → Verifica que existe "vault-jenkins-token"

# Verificar que el token tenga permisos
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$VAULT_JENKINS_TOKEN' && vault token lookup"
```

### El pipeline falla al obtener secretos

**Síntomas:** Error 403 o "permission denied" al acceder a Vault

**Solución:**
```bash
# Verificar que los secretos existan
VAULT_POD=$(kubectl get pod -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vault $VAULT_POD -- sh -c "export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN='$VAULT_ROOT_TOKEN' && vault kv get secret/demo-app"

# Si no existen, recrearlos ejecutando el script de inicialización de nuevo
# (pero con cuidado si ya hay datos importantes)
```

### El deployment falla

**Síntomas:** Pods en estado `Pending`, `Error` o `CrashLoopBackOff`

**Solución:**
```bash
# Ver eventos del namespace
kubectl get events -n demo-app --sort-by='.lastTimestamp'

# Ver logs del pod
kubectl logs -n demo-app -l app=demo-app --tail=100

# Ver detalles del pod
kubectl describe pod -n demo-app -l app=demo-app

# Verificar que el Secret existe y tiene valores
kubectl get secret demo-app-secret -n demo-app
kubectl describe secret demo-app-secret -n demo-app
```

**Causas comunes:**
- Imagen de Docker no disponible o incorrecta
- Secret no existe o no tiene las claves correctas
- Recursos insuficientes en el cluster
- Variables de entorno faltantes

### kubectl no encontrado en Jenkins

**Síntomas:** "kubectl: not found" en los logs del pipeline

**Solución:**
- El Jenkinsfile instala kubectl automáticamente en el stage "Preparar entorno"
- Si falla, verifica que el pod de Jenkins tenga acceso a internet
- Verifica los logs completos del pipeline para ver el error específico

## 📁 Estructura del Proyecto

```
devops-nodejs-devtree/
├── demo-app/                           # Manifiestos de la aplicación
│   ├── namespace.yaml                  # Define el namespace demo-app
│   ├── deployment.yaml                 # Define el Deployment (pods)
│   ├── service.yaml                    # Define el Service (exposición)
│   └── hpa.yaml                        # Define el HPA (auto-escalado)
│
├── infrastructure/
│   ├── vault/                          # Configuración de Vault
│   │   ├── namespace.yaml
│   │   ├── service-account.yaml        # ServiceAccount y RBAC
│   │   ├── configmap.yaml              # Configuración de Vault (vault.hcl)
│   │   ├── service.yaml                # Service ClusterIP
│   │   └── statefulset.yaml            # StatefulSet para Vault
│   │
│   └── jenkins/                        # Configuración de Jenkins
│       ├── namespace.yaml
│       ├── service-account.yaml        # ServiceAccount y RBAC
│       ├── persistent-volume-claim.yaml # Almacenamiento persistente
│       ├── configmap.yaml              # Lista de plugins
│       ├── deployment.yaml             # Deployment de Jenkins
│       └── service.yaml                # Service NodePort
│
├── jenkins/
│   ├── Jenkinsfile                     # Pipeline completo
│   ├── scripts/
│   │   └── get-vault-secrets.sh        # Script auxiliar (opcional)
│   └── jobs/
│       └── deploy-demo-app-config.xml  # Configuración del Job (referencia)
│
├── scripts/
│   ├── vault-init.sh                   # Inicializa y configura Vault
│   ├── verify-deployment.sh            # Verifica el despliegue
│   └── pre-check.sh                    # Verifica requisitos previos
│
└── README.md                           # Este archivo
```

## 🔄 Flujo del Pipeline

El pipeline (`jenkins/Jenkinsfile`) ejecuta estos stages en orden:

1. **Preparar entorno**
   - Instala `kubectl` si no está disponible
   - Instala `jq` si no está disponible
   - Verifica acceso a Kubernetes y Vault

2. **Obtener secretos de Vault**
   - Se autentica en Vault usando el token configurado
   - Obtiene todos los secretos de `secret/data/demo-app`
   - Convierte JSON a formato `.env`

3. **Crear Secret de Kubernetes**
   - Crea el namespace `demo-app` si no existe
   - Crea/actualiza el Secret `demo-app-secret` con los valores de Vault

4. **Desplegar manifiestos**
   - Aplica `namespace.yaml`
   - Aplica `deployment.yaml`
   - Aplica `service.yaml`
   - Aplica `hpa.yaml`

5. **Verificar despliegue**
   - Espera a que el deployment esté disponible
   - Muestra el estado de los recursos

## 🎓 Conceptos Importantes

### ¿Por qué Vault?
- **Seguridad**: Los secretos no están en código (Git)
- **Control de acceso**: Políticas definen quién puede leer qué
- **Auditoría**: Vault registra quién accede a secretos
- **Rotación**: Fácil actualizar secretos sin cambiar código

### ¿Por qué Jenkins?
- **Automatización**: Ejecuta el despliegue automáticamente
- **Integración**: Se conecta fácilmente con Git, Vault, Kubernetes
- **Pipeline como código**: El Jenkinsfile está versionado
- **Extensibilidad**: Plugins para casi cualquier herramienta

### ¿Por qué Kubernetes?
- **Escalabilidad**: Fácil escalar aplicaciones
- **Alta disponibilidad**: Múltiples réplicas
- **Gestión de recursos**: Control de CPU/memoria
- **Rolling updates**: Actualizaciones sin downtime

## 🧹 Limpieza

Para eliminar todos los recursos desplegados:

```bash
# Eliminar la aplicación
kubectl delete namespace demo-app

# Eliminar Jenkins
kubectl delete namespace jenkins

# Eliminar Vault (⚠️ Esto borrará todos los secretos)
kubectl delete namespace vault

# Si quieres eliminar todo y empezar de nuevo
kubectl delete namespace demo-app jenkins vault
```

## 🚀 Próximos Pasos

Este proyecto implementa el **primer Job** (despliegue con manifiestos YAML). Los siguientes pasos serían:

1. **Job 2: Terraform + Kubernetes**
   - Convertir los manifiestos YAML a código Terraform
   - Desplegar usando el provider de Kubernetes de Terraform

2. **Job 3: Terraform + Helm**
   - Crear un chart de Helm para la aplicación
   - Desplegar usando Terraform con el provider de Helm

## 📚 Recursos de Aprendizaje

### Documentación Oficial
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)

### Conceptos Clave
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)

## 🤝 Contribuciones

Si mejoras este proyecto o encuentras errores, las contribuciones son bienvenidas.

## 📝 Notas Adicionales

### Personalización de Secretos

Para agregar o modificar secretos:
1. Actualiza los secretos en Vault (ver sección "Gestión de Secretos")
2. Si agregas nuevos secretos, actualiza `demo-app/deployment.yaml` para usarlos
3. Ejecuta el pipeline nuevamente

### Personalización de la Imagen Docker

El `deployment.yaml` usa la imagen: `jsegomez/demo-app:build-12`

Para cambiar la imagen:
1. Modifica `demo-app/deployment.yaml` línea 18
2. Ejecuta el pipeline nuevamente

### Acceso a la Aplicación

Para acceder a la aplicación desde tu máquina local:

```bash
kubectl port-forward -n demo-app svc/demo-app 5000:80
```

Luego abre: `http://localhost:5000`

---

**¡Felicitaciones!** 🎉 Has implementado un pipeline CI/CD completo con gestión de secretos.

Para más detalles sobre los conceptos y cómo funciona cada parte, revisa los archivos YAML y el Jenkinsfile comentados en el proyecto.
