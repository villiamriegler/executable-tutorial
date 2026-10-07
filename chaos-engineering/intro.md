# Scratchpad

Log of the background setup:

```bash
cat /root/setup.log
```{{exec}}

What is running:

```bash
kubectl get pods,svc
```{{exec}}

The frontend page:

```bash
curl -s localhost:30080/
```{{exec}}

Call the backend from inside the cluster:

```bash
kubectl exec deploy/frontend -- wget -qO- http://backend:8080/items
```{{exec}}

Logs of the two services:

```bash
kubectl logs deploy/frontend
```{{exec}}

```bash
kubectl logs deploy/backend
```{{exec}}

30 seconds of traffic with a summary at the end:

```bash
echo "GET http://localhost:30080/" | vegeta attack -rate=10 -duration=30s -timeout=2s | vegeta report
```{{exec}}

Memory and Helm, needed for the Chaos Mesh install:

```bash
free -m; helm version
```{{exec}}
