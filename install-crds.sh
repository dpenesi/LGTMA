#!/bin/bash
# Fix for CRD size error in ArgoCD
# This script installs CRDs separately before deploying kube-prometheus-stack

set -e

echo "==> Applying Prometheus Operator CRDs Application (sync-wave: -5)"
kubectl apply -f apps/prometheus-operator-crds.yaml

echo ""
echo "==> Waiting for CRDs Application to sync..."
sleep 5

echo ""
echo "==> Checking CRDs Application status"
kubectl get application prometheus-operator-crds -n argocd

echo ""
echo "==> Verifying CRDs are installed"
kubectl get crds | grep monitoring.coreos.com

echo ""
echo "✅ CRDs installed successfully"
echo ""
echo "Now you can sync the kube-prometheus-stack Application:"
echo "  kubectl apply -f app-of-apps/root-observability.yaml"
echo "  OR"
echo "  argocd app sync kube-prometheus-stack"
