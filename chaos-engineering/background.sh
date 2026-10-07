#!/bin/bash
exec > /root/setup.log 2>&1
set -x

echo $$ > /root/.setup-pid
status() { echo "$1" >> /root/.setup-status; }

cd /root/chaos

status "Installing vegeta..."
curl -sL https://github.com/tsenart/vegeta/releases/download/v12.13.0/vegeta_12.13.0_linux_amd64.tar.gz | tar xz -C /usr/local/bin vegeta
status "vegeta installed"

status "Deploying services..."
kubectl create configmap backend-code --from-file=backend/app.py --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap frontend-code --from-file=frontend/app.py --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f backend/deployment.yaml -f frontend/deployment.yaml
kubectl rollout status deploy/backend --timeout=180s
kubectl rollout status deploy/frontend --timeout=180s
status "services deployed"

status "Installing Chaos Mesh..."
command -v helm >/dev/null || curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh --version 2.8.4 --namespace chaos-mesh --create-namespace \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set controllerManager.replicaCount=1 \
  --set dashboard.create=false \
  --set dnsServer.create=false
kubectl rollout status -n chaos-mesh deploy/chaos-controller-manager --timeout=300s
kubectl rollout status -n chaos-mesh ds/chaos-daemon --timeout=300s
status "Chaos Mesh installed"

touch /root/.setup-done
