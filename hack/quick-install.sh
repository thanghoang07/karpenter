#!/bin/bash
set -eu -o pipefail

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

main() {
  local command=${1:-'--apply'}
  if [[ $command = "--usage" ]]; then
    usage
  elif [[ $command = "--apply" ]]; then
    apply
    echo "Installation complete!"
  elif [[ $command = "--delete" ]]; then
    delete
    echo "Uninstallation complete!"
  else
    echo "Error: invalid argument: $command" >&2
    usage
    exit 22			# EINVAL
  fi
}

usage() {
  cat <<EOF
######################## USAGE ########################
hack/quick-install.sh          # Defaults to apply
hack/quick-install.sh --usage  # Displays usage
hack/quick-install.sh --apply  # Creates all resources
hack/quick-install.sh --delete # Deletes all resources
#######################################################
EOF
}

delete() {
  make delete || true
  helm uninstall cert-manager --namespace cert-manager || true
  helm uninstall kube-prometheus-stack --namespace monitoring || true
  kubectl delete namespace cert-manager monitoring || true
}

apply() {
  helm repo add jetstack https://charts.jetstack.io
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update

  certmanager
  prometheus
  make apply
}

# If this fails you may have an old installation hanging around. If it's just for
# testing, you can remove it with something like this (match the version to the version
# you installed).
#
# VERSION=$(kubectl get deployment cert-manager -n cert-manager -ojsonpath='{.spec.template.spec.containers[0].image}{"\n"}' | cut -f2 -d:)
# kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/${VERSION}/cert-manager.yaml
certmanager() {
  helm upgrade --install cert-manager jetstack/cert-manager \
    --atomic \
    --create-namespace \
    --namespace cert-manager \
    --version v1.0.0 \
    --set installCRDs=true
}

prometheus() {
  # Minimal install of prometheus operator.
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --atomic \
    --create-namespace \
    --namespace monitoring \
    --version 9.4.5 \
    --set alertmanager.enabled=false \
    --set grafana.enabled=false \
    --set kubeApiServer.enabled=false \
    --set kubelet.enabled=false \
    --set kubeControllerManager.enabled=false \
    --set coreDns.enabled=false \
    --set kubeDns.enabled=false \
    --set kubeEtcd.enabled=false \
    --set kubeScheduler.enabled=false \
    --set kubeProxy.enabled=false \
    --set kubeStateMetrics.enabled=false \
    --set nodeExporter.enabled=false \
    --set prometheus.enabled=false
}

main "$@"
