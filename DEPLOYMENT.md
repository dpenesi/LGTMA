# Guía de Despliegue - LGTMA Stack

## Paso 1: Reemplazar Placeholders

Antes de desplegar, debes reemplazar los siguientes placeholders en los archivos `charts-values/*.yaml`:

```bash
cd /home/dpenesi/Despliegues/InfaIA/Full-Observabilidad/LGTMA

# Ejemplo de reemplazo (ajusta los valores reales):
export AWS_REGION="us-east-1"
export ACCOUNT_ID="123456789012"
export BUCKET_LOKI="loki-bucket-name"
export BUCKET_MIMIR="mimir-bucket-name"
export BUCKET_TEMPO="tempo-bucket-name"
export LOKI_IRSA_ROLE="loki-irsa-role"
export MIMIR_IRSA_ROLE="mimir-irsa-role"
export TEMPO_IRSA_ROLE="tempo-irsa-role"

# Reemplazar en todos los archivos values
find charts-values/ -name "*.yaml" -type f -exec sed -i \
  -e "s|<AWS_REGION>|${AWS_REGION}|g" \
  -e "s|<ACCOUNT_ID>|${ACCOUNT_ID}|g" \
  -e "s|<BUCKET_LOKI>|${BUCKET_LOKI}|g" \
  -e "s|<BUCKET_MIMIR>|${BUCKET_MIMIR}|g" \
  -e "s|<BUCKET_TEMPO>|${BUCKET_TEMPO}|g" \
  -e "s|<LOKI_IRSA_ROLE_NAME>|${LOKI_IRSA_ROLE}|g" \
  -e "s|<MIMIR_IRSA_ROLE_NAME>|${MIMIR_IRSA_ROLE}|g" \
  -e "s|<TEMPO_IRSA_ROLE_NAME>|${TEMPO_IRSA_ROLE}|g" \
  {} \;

# Verificar cambios
git diff charts-values/

# Commit y push de los cambios
git add charts-values/
git commit -m "Configure AWS placeholders for eks-wispro-02"
git push origin main
```

## Paso 2: Aplicar o Actualizar Root Application

### Opción A: Si ya existe una aplicación "root" en ArgoCD

Actualiza la aplicación existente para apuntar a este repositorio:

```bash
kubectl -n argocd patch app root --type merge -p '{
  "spec": {
    "source": {
      "repoURL": "https://github.com/dpenesi/LGTMA.git",
      "targetRevision": "main",
      "path": "app-of-apps"
    }
  }
}'
```

### Opción B: Crear nueva Root Application

Si no existe ninguna aplicación root, créala desde cero:

```bash
kubectl apply -f app-of-apps/root-observability.yaml
```

## Paso 3: Verificar el Despliegue

### Verificar aplicaciones en ArgoCD

```bash
# Ver todas las aplicaciones
kubectl get applications -n argocd

# Esperar a que la root app se sincronice
kubectl wait --for=condition=Synced app/root-observability -n argocd --timeout=300s

# Ver el estado detallado de la root app
kubectl -n argocd describe app root-observability | egrep -i "sync|health"
```

### Verificar componentes individuales

```bash
# Ver todas las aplicaciones del stack
kubectl get applications -n argocd | grep -E "loki|mimir|tempo|grafana|alloy|kube-prometheus"

# Ver estado de sincronización
kubectl -n argocd get app -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

### Verificar pods en el namespace observability

```bash
# Ver todos los pods
kubectl -n observability get pods

# Esperar a que todos estén running
kubectl -n observability wait --for=condition=Ready pod --all --timeout=600s

# Ver eventos si hay problemas
kubectl -n observability get events --sort-by='.lastTimestamp' | tail -20
```

## Paso 4: Verificar Conectividad

### Verificar servicios

```bash
# Listar servicios
kubectl -n observability get svc

# Verificar endpoints
kubectl -n observability get endpoints
```

### Port-forward para acceder a Grafana

```bash
# Port-forward a Grafana
kubectl -n observability port-forward svc/grafana 3000:80

# Abrir en navegador: http://localhost:3000
# Usuario: admin
# Password: CHANGEME (cambiar después del primer login)
```

## Paso 5: Troubleshooting

### Ver logs de ArgoCD

```bash
# Application controller logs
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=100 -f

# Repo server logs (si hay errores de autenticación)
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-repo-server --tail=100 -f
```

### Ver logs de un pod específico

```bash
# Ejemplo: Loki
kubectl -n observability logs -l app.kubernetes.io/name=loki --tail=100

# Ejemplo: Mimir
kubectl -n observability logs -l app.kubernetes.io/name=mimir --tail=100
```

### Forzar resincronización

```bash
# Forzar sync de root app
kubectl -n argocd patch app root-observability -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' --type=merge

# O usar ArgoCD CLI
argocd app sync root-observability
```

### Verificar permisos IRSA

```bash
# Ver service accounts
kubectl -n observability get sa

# Verificar annotations de IRSA
kubectl -n observability get sa loki -o jsonpath='{.metadata.annotations}'
kubectl -n observability get sa mimir -o jsonpath='{.metadata.annotations}'
kubectl -n observability get sa tempo -o jsonpath='{.metadata.annotations}'
```

## Paso 6: Validar Stack Completo

### Verificar flujo de datos

```bash
# Verificar que Prometheus escribe a Mimir
kubectl -n observability logs -l app.kubernetes.io/name=prometheus --tail=50 | grep remote_write

# Verificar que Alloy envía logs a Loki
kubectl -n observability logs -l app.kubernetes.io/name=alloy --tail=50

# Verificar métricas en Grafana
# 1. Port-forward a Grafana
# 2. Ir a Explore > Mimir
# 3. Ejecutar query: up
```

### Health checks

```bash
# Verificar health de todas las apps
kubectl -n argocd get applications -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status

# Esperar a que todas estén Healthy y Synced
```

## Comandos Útiles

```bash
# Ver recursos de todas las aplicaciones
kubectl -n argocd get app -o wide

# Eliminar y recrear una aplicación específica
kubectl -n argocd delete app loki
kubectl -n argocd patch app root-observability -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' --type=merge

# Ver secretos creados (si existen)
kubectl -n observability get secrets

# Ver configmaps
kubectl -n observability get cm
```

## Rollback

Si necesitas hacer rollback:

```bash
# Eliminar todas las aplicaciones
kubectl -n argocd delete app root-observability

# Esto eliminará automáticamente todas las aplicaciones hijas
# Para mantener los recursos, edita primero y quita el finalizer:
kubectl -n argocd patch app root-observability -p '{"metadata":{"finalizers":[]}}' --type=merge
```

## Acceso a Grafana

Una vez todo esté desplegado:

```bash
# Port-forward
kubectl -n observability port-forward svc/grafana 3000:80

# O crear un Ingress/LoadBalancer según tu infraestructura
```

**Credenciales por defecto:**
- Usuario: `admin`
- Password: `CHANGEME` (cambiar inmediatamente después del primer login)

**Datasources pre-configurados:**
- Mimir (Prometheus) - Default
- Loki (Logs)
- Tempo (Traces)

## Notas Importantes

1. **Placeholders**: Asegúrate de haber reemplazado TODOS los placeholders antes del despliegue
2. **IRSA**: Los roles IAM deben existir y tener las políticas correctas para S3
3. **Buckets S3**: Deben existir y ser accesibles desde el cluster EKS
4. **Seguridad**: Cambia la password de Grafana inmediatamente
5. **Monitoreo**: Verifica los logs de cada componente para detectar errores temprano
