#!/bin/bash
exec > /root/setup.log 2>&1
set -x

cd /root/chaos

curl -sL https://github.com/tsenart/vegeta/releases/download/v12.13.0/vegeta_12.13.0_linux_amd64.tar.gz | tar xz -C /usr/local/bin vegeta

kubectl create configmap backend-code --from-file=backend/app.py --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap frontend-code --from-file=frontend/app.py --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f backend/deployment.yaml -f frontend/deployment.yaml
kubectl rollout status deploy/backend --timeout=180s
kubectl rollout status deploy/frontend --timeout=180s

touch /root/.setup-done
