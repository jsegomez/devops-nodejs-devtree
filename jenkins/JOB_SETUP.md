# Configuración del Job de Jenkins

## Opción 1: Usando Pipeline desde SCM (Recomendado)

1. Accede a Jenkins: `http://localhost:30080` (o la URL de tu cluster)

2. Haz clic en **"New Item"**

3. Nombre: `deploy-demo-app`

4. Selecciona **"Pipeline"** y haz clic en **"OK"**

5. En la configuración del Job:
   - **Pipeline definition**: Selecciona **"Pipeline script from SCM"**
   - **SCM**: Selecciona **"Git"**
   - **Repository URL**: URL de tu repositorio Git
   - **Credentials**: (si es privado, agrega credenciales)
   - **Branches to build**: `*/main` o la rama que uses
   - **Script Path**: `jenkins/Jenkinsfile`

6. Guarda y haz clic en **"Build Now"**

## Opción 2: Pipeline declarativo directo

1. Crea un nuevo Pipeline Job

2. En **"Pipeline definition"**, selecciona **"Pipeline script"**

3. Copia el contenido del `jenkins/Jenkinsfile` directamente en el editor

4. Guarda

## Configurar credenciales de Vault

1. Ve a **"Manage Jenkins"** > **"Credentials"**

2. Selecciona el dominio (General) o crea uno específico

3. Haz clic en **"Add Credentials"**

4. Configura:
   - **Kind**: Secret text
   - **Secret**: [Tu token de Vault obtenido del script vault-init.sh]
   - **ID**: `vault-jenkins-token`
   - **Description**: Token de Vault para Jenkins

5. Guarda

## Verificar el Job

Una vez configurado el Job, puedes ejecutarlo y debería:
1. Obtener secretos de Vault
2. Crear el Secret de Kubernetes
3. Desplegar los manifiestos
4. Verificar el despliegue
