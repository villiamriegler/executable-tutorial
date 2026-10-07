# Experiment 1: Kill the backend pod

## Hypothesis

Kubernetes restarts pods that die. So the hypothesis, and it is the one most people hold, is:

> **Losing one backend pod has no effect on users.**

To test it we need to know what "no effect" looks like. Send traffic to the frontend for 10 seconds; `vegeta` fires 50 requests per second and summarises what came back:

```bash
echo "GET http://localhost:30080/" | vegeta attack -duration=10s | tee results.bin | vegeta report
```{{exec}}

> Success is 100% and every status code is 200. If the hypothesis holds, the same traffic during the experiment looks the same.

## Experiment

The experiment is a Chaos Mesh resource, saved as `/root/chaos/experiments/pod-kill.yaml`. It kills one pod with the label `app=backend`:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: backend-pod-kill
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - default
    labelSelectors:
      app: backend
```

Apply it and send the same traffic right away:

```bash
kubectl apply -f /root/chaos/experiments/pod-kill.yaml
echo "GET http://localhost:30080/" | vegeta attack -duration=10s | tee results.bin | vegeta report
```{{exec}}

> Success is well below 100% and there are 502s: the frontend could not reach the backend. **The hypothesis was wrong.**

<details>
<summary>When exactly did requests fail?</summary>

![Requests during the experiment](./images/pod-kill-timeline.svg)

The report only has totals. This groups the same results by second and status code:

```bash
vegeta encode --to=csv results.bin | awk -F, 'NR==1{t0=$1} {n[int(($1-t0)/1e9)" "$2]++} END{for (k in n) print k, n[k]}' | sort -n | column -t -N second,status,requests
```{{exec}}

Every request failed for about a second and a half, right after the pod was deleted, then everything was fine again.

</details>

## What happened

Kubernetes did its job. One of its main responsibilities is to keep a Deployment in its declared state, and the backend Deployment says "one pod", so the moment Chaos Mesh deleted that pod, Kubernetes created a new one:

```bash
kubectl get pods
```{{exec}}

> The backend pod is back, but look at `AGE`: it is only seconds old. This is a different pod than the one you started with.

So the pod healed, and from Kubernetes' point of view nothing is wrong. Users saw it differently: with a single replica there was nothing to answer their requests between the moment the old pod was deleted and the moment the new one was scheduled, started and listening. That gap is the downtime.

![The backend pod is deleted and nothing answers](./images/architecture-pod-killed.svg)

## Fix

The simplest way to avoid downtime when a pod is killed is redundancy: run more than one replica, so another pod answers while the killed one is being replaced. The patch below does that, and adds a readiness probe so the replacement pod only receives traffic once it responds, not as soon as its container exists. It is saved as `/root/chaos/backend/patch.yaml`:

```yaml
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: backend
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            periodSeconds: 1
```

Apply it to the Deployment and wait for the rollout:

```bash
kubectl patch deployment backend --patch-file /root/chaos/backend/patch.yaml
kubectl rollout status deployment backend
```{{exec}}

![Two backend pods behind the Service](./images/architecture-2-replicas.svg)

## Run the experiment again

A `PodChaos` kills once, so delete it before applying it again:

```bash
kubectl delete -f /root/chaos/experiments/pod-kill.yaml
kubectl apply -f /root/chaos/experiments/pod-kill.yaml
echo "GET http://localhost:30080/" | vegeta attack -duration=10s | tee results.bin | vegeta report
```{{exec}}

> A pod was killed again, and this time the requests succeeded: the other replica answered while the replacement started.

![One pod is deleted, the other answers](./images/architecture-2-replicas-pod-killed.svg)

The same experiment now passes. That is the point of writing the experiment down: a fix is only real once the experiment that found the problem no longer finds it.
