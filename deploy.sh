#!/bin/bash
# Script interactivo para desplegar LGTMA Stack en Kubernetes

echo "======================================================================"
echo "LGTMA Stack - Comandos de Despliegue"
echo "Repositorio: https://github.com/dpenesi/LGTMA.git"
echo "======================================================================"
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}PASO 1: Configurar placeholders con valores reales${NC}"
echo ""
echo "Antes de continuar, debes reemplazar los placeholders en charts-values/*.yaml"
echo "Edita estas variables con tus valores reales:"
echo ""
cat << 'EOF'
export AWS_REGION="us-east-1"  # Tu región AWS
export ACCOUNT_ID="123456789012"  # Tu Account ID
export CLUSTER_NAME="my-k8s-cluster"  # Nombre de tu cluster
export BUCKET_LOKI="loki-bucket-name"  # Bucket S3 para Loki
export BUCKET_MIMIR="mimir-bucket-name"  # Bucket S3 para Mimir
export BUCKET_TEMPO="tempo-bucket-name"  # Bucket S3 para Tempo
export LOKI_IRSA_ROLE="loki-irsa-role"  # Rol IRSA de Loki
export MIMIR_IRSA_ROLE="mimir-irsa-role"  # Rol IRSA de Mimir
export TEMPO_IRSA_ROLE="tempo-irsa-role"  # Rol IRSA de Tempo

# Reemplazar en todos los archivos
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

# Commit y push
git add charts-values/for my environment
git commit -m "Configure AWS resources for <CLUSTER_NAME>"
git push origin main
EOF

echo ""
read -p "¿Has configurado los placeholders y hecho push? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Por favor, configura los placeholders primero.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}PASO 2: Actualizar o crear Root Application en ArgoCD${NC}"
echo ""
echo "Opción A - Si ya existe una app 'root' en ArgoCD, actualizarla:"
echo ""
echo "kubectl -n argocd patch app root --type merge -p '{"
echo "  \"spec\": {"
echo "    \"source\": {"
echo "      \"repoURL\": \"https://github.com/dpenesi/LGTMA.git\","
echo "      \"targetRevision\": \"main\","
echo "      \"path\": \"app-of-apps\""
echo "    }"
echo "  }"
echo "}'"
echo ""
echo "Opción B - Crear nueva Root Application:"
echo ""
echo "kubectl apply -f app-of-apps/root-observability.yaml"
echo ""
read -p "¿Qué opción prefieres? (A/B) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Aa]$ ]]; then
    echo -e "${GREEN}Ejecutando Opción A: Actualizando app root existente...${NC}"
    kubectl -n argocd patch app root --type merge -p '{
      "spec": {
        "source": {
          "repoURL": "https://github.com/dpenesi/LGTMA.git",
          "targetRevision": "main",
          "path": "app-of-apps"
        }
      }
    }'
else
    echo -e "${GREEN}Ejecutando Opción B: Creando nueva root application...${NC}"
    kubectl apply -f app-of-apps/root-observability.yaml
fi

echo ""
echo -e "${YELLOW}PASO 3: Verificar despliegue${NC}"
echo ""
echo "Esperando sincronización de ArgoCD..."
sleep 10

echo ""
echo -e "${GREEN}Applications en ArgoCD:${NC}"
kubectl get applications -n argocd

echo ""
echo -e "${GREEN}Estado de sincronización:${NC}"
kubectl -n argocd get app -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

echo ""
echo -e "${YELLOW}Esperando que los pods se inicien (esto puede tomar varios minutos)...${NC}"
echo ""
echo "Puedes monitorear en tiempo real con:"
echo "  watch 'kubectl -n observability get pods'"
echo ""

echo -e "${GREEN}Pods en namespace observability:${NC}"
kubectl -n observability get pods

echo ""
echo "======================================================================"
echo -e "${GREEN}Despliegue iniciado exitosamente!${NC}"
echo "======================================================================"
echo ""
echo "Para acceder a Grafana:"
echo "  kubectl -n observability port-forward svc/grafana 3000:80"
echo "  URL: http://localhost:3000"
echo "  Usuario: admin"
echo "  Password: CHANGEME"
echo ""
echo "Comandos útiles de verificación:"
echo "  kubectl get applications -n argocd"
echo "  kubectl -n observability get pods"
echo "  kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=50"
echo ""
echo "Para más información, consulta:"
echo "  - README.md"
echo "  - DEPLOYMENT.md"
echo ""
echo "Repositorio: https://github.com/dpenesi/LGTMA"
echo "======================================================================"
