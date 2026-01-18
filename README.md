# LGTMA Stack - GitOps Observability

Repositorio GitOps para desplegar el stack completo de observabilidad (Loki, Grafana, Tempo, Mimir, Alloy) en clusters Kubernetes usando ArgoCD con el patrón "app-of-apps".

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

✅ Kubernetes cluster (EKS, GKE, AKS, on-prem)
✅ ArgoCD instalado en namespace `argocd`  
✅ Namespace `observability` (se crea automáticamente)
✅ **Para AWS**: Buckets S3 e IRSA roles configurados para Loki, Mimir y Tempo  
✅ **Para otros clouds**: Configurar storage backend apropiado

## Configuración de Placeholders

⚠️ **IMPORTANTE**: Antes de aplicar, debes configurar los siguientes valores en los archivos `charts-values/*.yaml`:

### Para AWS/EKS:
- `<AWS_REGION>` - Región de AWS (ej: us-east-1)
- `<ACCOUNT_ID>` - ID de la cuenta AWS
- `<BUCKET_LOKI>` - Nombre del bucket S3 para Loki
- `<BUCKET_MIMIR>` - Nombre del bucket S3 para Mimir
- `<BUCKET_TEMPO>` - Nombre del bucket S3 para Tempo
- `<LOKI_IRSA_ROLE_NAME>` - Nombre del rol IRSA para Loki
- `<MIMIR_IRSA_ROLE_NAME>` - Nombre del rol IRSA para Mimir
- `<TEMPO_IRSA_ROLE_NAME>` - Nombre del rol IRSA para Tempo
- `<CLUSTER_NAME>` - Nombre de tu cluster para labels

### Para GCP/GKE o Azure/AKS:
Adaptar la configuración de storage en cada values file según tu cloud provider.

## Despliegue

### 1. Fork o clone este repositorio

```bash
git clone https://github.com/dpenesi/LGTMA.git
cd LGTMA
```

### 2. Configurar valores para tu entorno

```bash
# Ejemplo para AWS
export AWS_REGION="us-east-1"
export ACCOUNT_ID="123456789012"
export CLUSTER_NAME="my-k8s-cluster"
export BUCKET_LOKI="my-loki-bucket"
export BUCKET_MIMIR="my-mimir-bucket"
export BUCKET_TEMPO="my-tempo-bucket"
export LOKI_IRSA_ROLE="loki-s3-role"
export MIMIR_IRSA_ROLE="mimir-s3-role"
export TEMPO_IRSA_ROLE="tempo-s3-role"

# Reemplazar placeholders
find charts-values/ -name "*.yaml" -type f -exec sed -i \
  -e "s|<AWS_REGION>|${AWS_REGION}|g" \
  -e "s|<ACCOUNT_ID>|${ACCOUNT_ID}|g" \
  -e "s|<CLUSTER_NAME>|${CLUSTER_NAME}|g" \
  -e "s|<BUCKET_LOKI>|${BUCKET_LOKI}|g" \
  -e "s|<BUCKET_MIMIR>|${BUCKET_MIMIR}|g" \
  -e "s|<BUCKET_TEMPO>|${BUCKET_TEMPO}|g" \
  -e "s|<LOKI_IRSA_ROLE_NAME>|${LOKI_IRSA_ROLE}|g" \
  -e "s|<MIMIR_IRSA_ROLE_NAME>|${MIMIR_IRSA_ROLE}|g" \
  -e "s|<TEMPO_IRSA_ROLE_NAME>|${TEMPO_IRSA_ROLE}|g" \
  {} \;
```

### 3. Actualizar repoURL en los manifiestos

Si hiciste fork del repositorio, actualiza la URL:

```bash
# Reemplazar con tu fork
export REPO_URL="https://github.com/YOUR_ORG/LGTMA.git"

sed -i "s|https://github.com/dpenesi/LGTMA.git|${REPO_URL}|g" app-of-apps/root-observability.yaml
sed -i "s|https://github.com/dpenesi/LGTMA.git|${REPO_URL}|g" apps/observability-stack.yaml
```

### 4. Commit y push cambios

```bash
git add .
git commit -m "Configure for my environment"
git push origin main
```

### 5. Aplicar Root Application

```bash
kubectl apply -f app-of-apps/root-observability.yaml
```

### 6. Verificar despliegue

```bash
# Ver aplicaciones en ArgoCD
kubectl get applications -n argocd

# Ver pods
kubectl -n observability get pods

# Acceder a Grafana
kubectl -n observability port-forward svc/grafana 3000:80
# http://localhost:3000 - admin/CHANGEME
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

## Personalización

### Ajustar replicas y recursos

Edita los archivos en `charts-values/` según tus necesidades:
- Replicas de cada componente
- Requests y limits de CPU/memoria
- Tamaño de storage
- Retention periods

### Datasources en Grafana

Los datasources vienen pre-configurados:
- **Mimir**: Métricas (default)
- **Loki**: Logs
- **Tempo**: Traces con correlación a logs y métricas

## Troubleshooting

```bash
# Ver logs de ArgoCD
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Verificar sync status
kubectl -n argocd get applications

# Ver eventos en observability namespace
kubectl -n observability get events --sort-by='.lastTimestamp'

# Logs de componentes específicos
kubectl -n observability logs -l app.kubernetes.io/name=loki
kubectl -n observability logs -l app.kubernetes.io/name=mimir
```

## Documentación Adicional

- [DEPLOYMENT.md](DEPLOYMENT.md) - Guía detallada de despliegue
- [deploy.sh](deploy.sh) - Script interactivo de despliegue

## Seguridad

- ✅ **Sin secretos**: Este repositorio NO contiene credenciales
- ✅ **IRSA**: Autenticación con S3 mediante IAM roles
- ⚠️ **Grafana password**: Cambiar después del primer login
- 🔐 **Ingress**: Configurar TLS y autenticación según necesidades

## Compatibilidad

- Kubernetes 1.24+
- ArgoCD 2.8+
- Helm charts:
  - grafana/grafana 7.3.0
  - grafana/loki 6.16.0
  - grafana/mimir-distributed 5.4.0
  - grafana/tempo-distributed 1.9.0
  - grafana/alloy 0.5.0
  - prometheus-community/kube-prometheus-stack 56.0.0

## Contribuciones

Issues y pull requests son bienvenidos para mejorar este stack de observabilidad.

## Licencia

MIT License - Siéntete libre de usar y modificar según tus necesidades.
