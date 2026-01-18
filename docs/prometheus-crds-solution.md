# Prometheus Operator CRDs - Solución GitOps

## Problema
ArgoCD falla al instalar los CRDs del Prometheus Operator con error:
```
CustomResourceDefinition "prometheuses.monitoring.coreos.com" invalid: metadata.annotations Too long
```

Esto ocurre porque los CRDs del Prometheus Operator son muy grandes y exceden el límite de tamaño de anotaciones de Kubernetes cuando ArgoCD intenta gestionarlos.

## Solución

### Arquitectura
1. **Application separada para CRDs** (`prometheus-operator-crds`)
   - Instala SOLO los CRDs del chart kube-prometheus-stack
   - Usa `ServerSideApply=true` para evitar límites de anotaciones
   - Sync wave: `-5` (se instala primero)
   - Auto-prune: `false` (protege CRDs de borrado accidental)

2. **Application principal modificada** (`kube-prometheus-stack`)
   - Deshabilita instalación de CRDs: `crds.enabled=false`
   - Sync wave: `0` (se instala después de CRDs)
   - Depende de CRDs preinstalados

### Archivos Involucrados

#### `apps/prometheus-operator-crds.yaml` (NUEVO)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-operator-crds
  annotations:
    argocd.argoproj.io/sync-wave: "-5"  # Primera ola
spec:
  syncPolicy:
    automated:
      prune: false  # No borrar CRDs automáticamente
    syncOptions:
      - ServerSideApply=true  # Evitar límite de anotaciones
  source:
    repoURL: https://github.com/prometheus-community/helm-charts.git
    targetRevision: kube-prometheus-stack-56.0.0
    path: charts/kube-prometheus-stack/charts/crds/crds
```

#### `apps/observability-stack.yaml` (MODIFICADO)
```yaml
metadata:
  name: kube-prometheus-stack
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Segunda ola
spec:
  sources:
    - helm:
        parameters:
          - name: crds.enabled
            value: "false"  # No instalar CRDs
```

#### `charts-values/kube-prom-values.yaml` (MODIFICADO)
```yaml
crds:
  enabled: false  # CRDs gestionados por Application separada
```

### Orden de Instalación (Sync Waves)

```
Wave -5: prometheus-operator-crds
  ├─ alertmanagerconfigs.monitoring.coreos.com
  ├─ alertmanagers.monitoring.coreos.com
  ├─ podmonitors.monitoring.coreos.com
  ├─ probes.monitoring.coreos.com
  ├─ prometheusagents.monitoring.coreos.com  ← Este CRD causaba error
  ├─ prometheuses.monitoring.coreos.com      ← Este CRD causaba error
  ├─ prometheusrules.monitoring.coreos.com
  ├─ scrapeconfigs.monitoring.coreos.com
  ├─ servicemonitors.monitoring.coreos.com
  └─ thanosrulers.monitoring.coreos.com

Wave 0: kube-prometheus-stack
  ├─ prometheus-operator (deployment)
  ├─ prometheus (statefulset)
  ├─ alertmanager (statefulset)
  └─ ... otros recursos
```

## Deployment

### Opción 1: Deployment Automático (Recomendado)
Si usas el pattern app-of-apps:
```bash
# El root app detecta automáticamente el nuevo archivo
kubectl apply -f app-of-apps/root-observability.yaml

# ArgoCD sincroniza en orden:
# 1. prometheus-operator-crds (wave -5)
# 2. kube-prometheus-stack (wave 0)
```

### Opción 2: Instalación Manual Paso a Paso
```bash
# 1. Instalar CRDs primero
./install-crds.sh

# 2. Verificar que los CRDs están instalados
kubectl get crds | grep monitoring.coreos.com

# 3. Sincronizar kube-prometheus-stack
argocd app sync kube-prometheus-stack
```

### Opción 3: Script Asistido
```bash
./install-crds.sh
# El script:
# - Aplica prometheus-operator-crds Application
# - Espera a que los CRDs se instalen
# - Verifica la instalación
# - Muestra comandos para continuar
```

## Verificación

### Verificar CRDs Application
```bash
kubectl get application prometheus-operator-crds -n argocd
argocd app get prometheus-operator-crds
```

### Verificar CRDs Instalados
```bash
# Listar todos los CRDs del Prometheus Operator
kubectl get crds | grep monitoring.coreos.com

# Verificar un CRD específico (el que causaba error)
kubectl get crd prometheuses.monitoring.coreos.com -o yaml | head -20
```

### Verificar kube-prometheus-stack
```bash
# Ver que NO intenta instalar CRDs
kubectl get application kube-prometheus-stack -n argocd -o yaml | grep -A5 parameters

# Verificar que los pods arrancan correctamente
kubectl get pods -n observability -l app.kubernetes.io/name=kube-prometheus-stack
```

## Troubleshooting

### Error: CRDs Application en estado Progressing
```bash
# Ver logs de sync
argocd app get prometheus-operator-crds

# Forzar resincronización
argocd app sync prometheus-operator-crds --force
```

### Error: kube-prometheus-stack no encuentra CRDs
```bash
# Verificar que los CRDs existen
kubectl get crds | grep monitoring.coreos.com | wc -l
# Debe mostrar 10 CRDs

# Verificar sync wave order
kubectl get applications -n argocd -o custom-columns=\
NAME:.metadata.name,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave
```

### Rollback: Volver a instalación tradicional
Si necesitas revertir este cambio:
```bash
# 1. Eliminar Application de CRDs
kubectl delete application prometheus-operator-crds -n argocd

# 2. Habilitar CRDs en kube-prometheus-stack
# En charts-values/kube-prom-values.yaml:
crds:
  enabled: true

# 3. Remover parámetro helm y sync wave en apps/observability-stack.yaml
# 4. Sync
argocd app sync kube-prometheus-stack --force
```

## Ventajas de esta Solución

✅ **GitOps Compliant**: Todo declarativo en Git  
✅ **Reusable**: Funciona en cualquier cluster  
✅ **Safe**: CRDs protegidos con `prune: false`  
✅ **Orden Garantizado**: Sync waves aseguran dependencias  
✅ **Server-Side Apply**: Evita límites de anotaciones  
✅ **Idempotente**: Reaplicable sin efectos secundarios  
✅ **Documentado**: Comentarios inline en manifests  

## Referencias

- [ArgoCD Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Kubernetes Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
- [Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator/tree/main/example/prometheus-operator-crd)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
