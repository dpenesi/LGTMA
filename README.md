# LGTMA Stack - GitOps Observability

Repositorio GitOps para desplegar el stack completo de observabilidad (Loki, Grafana, Tempo, Mimir, Alloy) en el cluster EKS **eks-wispro-02** usando ArgoCD con el patrón "app-of-apps".

## Stack de Componentes

- **Grafana**: Visualización y dashboards
- **Loki**: Agregación de logs
- **Tempo**: Trazado distribuido
- **Mimir**: Métricas de largo plazo
- **Alloy**: Colector de logs y métricas
- **Kube-Prometheus-Stack**: Prometheus, Alertmanager y service monitors

## Estructura del Repositorio

```
.
├── app-of-apps/
│   └── root-observability.yaml    # Root Application (app-of-apps)
├── apps/
│   ├── observability-namespace.yaml
│   └── observability-stack.yaml   # Applications individuales
└── charts-values/
    ├── grafana-values.yaml
    ├── loki-values.yaml
    ├── mimir-values.yaml
    ├── tempo-values.yaml
    ├── alloy-values.yaml
    └── kube-prom-values.yaml
```

## Pre-requisitos

✅ ArgoCD instalado en namespace `argocd`  
✅ Namespace `observability` creado  
✅ Buckets S3 creados por Terraform  
✅ IRSA roles configurados para Loki, Mimir y Tempo  

## Configuración de Placeholders

⚠️ **IMPORTANTE**: Antes de aplicar, debes reemplazar los siguientes placeholders en los archivos `charts-values/*.yaml`:

- `<AWS_REGION>` - Región de AWS (ej: us-east-1)
- `<ACCOUNT_ID>` - ID de la cuenta AWS
- `<BUCKET_LOKI>` - Nombre del bucket S3 para Loki
- `<BUCKET_MIMIR>` - Nombre del bucket S3 para Mimir
- `<BUCKET_TEMPO>` - Nombre del bucket S3 para Tempo
- `<LOKI_IRSA_ROLE_NAME>` - Nombre del rol IRSA para Loki
- `<MIMIR_IRSA_ROLE_NAME>` - Nombre del rol IRSA para Mimir
- `<TEMPO_IRSA_ROLE_NAME>` - Nombre del rol IRSA para Tempo

## Despliegue

### 1. Aplicar la Root Application

Si ya existe una aplicación `root` en ArgoCD, actualízala para apuntar a este repositorio:

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

O crea la aplicación root desde cero:

```bash
kubectl apply -f app-of-apps/root-observability.yaml
```

### 2. Verificar el despliegue

```bash
# Ver todas las aplicaciones en ArgoCD
kubectl get applications -n argocd

# Ver el estado de los pods en el namespace observability
kubectl -n observability get pods

# Ver detalles de la aplicación root
kubectl -n argocd describe app root-observability | egrep -i "sync|health"

# Ver logs de ArgoCD para troubleshooting
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

### 3. Acceder a Grafana

```bash
# Port-forward a Grafana
kubectl -n observability port-forward svc/grafana 3000:80

# Credenciales por defecto (CAMBIAR):
# Usuario: admin
# Password: CHANGEME
```

## Sincronización y Troubleshooting

```bash
# Forzar sincronización de la root app
kubectl -n argocd patch app root-observability -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' --type=merge

# Ver eventos de ArgoCD
kubectl -n argocd get events --sort-by='.lastTimestamp'

# Ver configuración de una aplicación específica
kubectl -n argocd get app loki -o yaml

# Revisar si hay errores de autenticación con el repo
kubectl -n argocd describe app root-observability | grep -A 10 "Conditions"
```

## Arquitectura de Datos

```
┌─────────────────────────────────────────────────────┐
│                    Grafana                          │
│          (Visualización y Dashboards)               │
└──────┬──────────┬──────────────┬───────────────────┘
       │          │              │
       ▼          ▼              ▼
   ┌──────┐   ┌──────┐      ┌──────┐
   │ Mimir│   │ Loki │      │Tempo │
   │(Métr)│   │(Logs)│      │(Traces)
   └───▲──┘   └──▲───┘      └──▲───┘
       │         │             │
       │         │             │
   ┌───┴─────────┴─────────────┴────┐
   │         Alloy                   │
   │  (Colector y Pipeline)          │
   └───▲─────────────────────────────┘
       │
   ┌───┴────────────────────────────┐
   │    kube-prometheus-stack       │
   │  (Prometheus + ServiceMonitors)│
   └────────────────────────────────┘
```

## Notas Importantes

- ✅ **Sin secretos**: Este repositorio NO contiene credenciales. Los buckets y roles IAM se configuran mediante placeholders.
- ✅ **IRSA**: La autenticación con S3 se realiza mediante IRSA (IAM Roles for Service Accounts), sin claves estáticas.
- ✅ **GitOps puro**: Cualquier cambio en la configuración debe hacerse vía commit al repositorio.
- ⚠️ **Grafana password**: Cambiar el password de admin después del primer login.

## Soporte

Para issues o mejoras, crear un issue en este repositorio.
