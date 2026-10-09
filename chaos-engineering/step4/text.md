# Putting it together: chaining experiments

Both experiments were run by hand, one at a time: apply the chaos, run vegeta, read the report. That is fine for two experiments. With ten, or when you want to rerun all of them after a big change, you want to chain them and have the hypotheses checked for you.

## A workflow with status checks

Chaos Mesh can chain experiments in a `Workflow` and, in parallel with each one, run a `StatusCheck`: a probe the Chaos Mesh controller runs from inside the cluster, with a pass criterion. If a check fails, the workflow is aborted. So the hypotheses from the two experiments become checks:

- while a backend pod is killed, `GET /` must answer `200`;
- while the network is cut, `GET /health` must answer `200`, and `GET /` must answer `502`, both within a second.

The workflow, saved as `/root/chaos/experiments/test.yaml`:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: resilience-test
spec:
  entry: entry
  templates:
    # Run the two experiments one after the other.
    - name: entry
      templateType: Serial
      children:
        - pod-dies
        - network-partition

    # Experiment 1: kill a backend pod; the product page must keep answering 200.
    # The check starts first; the pod is killed 3 seconds in, so the check sees the gap.
    - name: pod-dies
      templateType: Parallel
      children:
        - products-keep-working
        - kill-backend-pod-after-3s
    - name: products-keep-working
      templateType: StatusCheck
      deadline: 13s
      abortWithStatusCheck: true
      statusCheck:
        mode: Continuous
        type: HTTP
        duration: 10s
        intervalSeconds: 1
        timeoutSeconds: 1
        failureThreshold: 3
        successThreshold: 1
        http:
          url: http://frontend.default.svc:8080/
          method: GET
          criteria:
            statusCode: "200"
    - name: kill-backend-pod-after-3s
      templateType: Serial
      children:
        - wait-3s
        - kill-backend-pod
    - name: wait-3s
      templateType: Suspend
      deadline: 3s
    - name: kill-backend-pod
      templateType: PodChaos
      deadline: 5s
      podChaos:
        action: pod-kill
        mode: one
        selector:
          namespaces:
            - default
          labelSelectors:
            app: backend

    # Experiment 2: cut the network to the backend; /health must keep answering 200
    # and the product page must answer 502 within a second instead of hanging.
    # The network is cut first; the checks start 3 seconds in, once the cut is in effect.
    - name: network-partition
      templateType: Parallel
      children:
        - cut-network
        - health-keeps-working-after-3s
        - products-fail-fast-after-3s
    - name: cut-network
      templateType: NetworkChaos
      deadline: 20s
      networkChaos:
        action: partition
        mode: all
        selector:
          namespaces:
            - default
          labelSelectors:
            app: frontend
        direction: to
        target:
          mode: all
          selector:
            namespaces:
              - default
            labelSelectors:
              app: backend
    - name: health-keeps-working-after-3s
      templateType: Serial
      children:
        - wait-3s
        - health-keeps-working
    - name: health-keeps-working
      templateType: StatusCheck
      deadline: 15s
      abortWithStatusCheck: true
      statusCheck:
        mode: Continuous
        type: HTTP
        duration: 12s
        intervalSeconds: 1
        timeoutSeconds: 1
        failureThreshold: 3
        successThreshold: 1
        http:
          url: http://frontend.default.svc:8080/health
          method: GET
          criteria:
            statusCode: "200"
    - name: products-fail-fast-after-3s
      templateType: Serial
      children:
        - wait-3s
        - products-fail-fast
    - name: products-fail-fast
      templateType: StatusCheck
      deadline: 15s
      abortWithStatusCheck: true
      statusCheck:
        mode: Continuous
        type: HTTP
        duration: 12s
        intervalSeconds: 1
        timeoutSeconds: 1
        failureThreshold: 3
        successThreshold: 1
        http:
          url: http://frontend.default.svc:8080/
          method: GET
          criteria:
            statusCode: "502"
```

`failureThreshold: 3` means three failed probes in a row fail the check, so a single request that happens to be in flight when the pod dies does not fail the run. The `Suspend` steps order things inside each phase: the check is running before the pod is killed, and the network is cut before its checks start.

### Step 1: Run the workflow

A workflow starts as soon as it is applied. Apply it and wait for it to finish, about half a minute:

```bash
kubectl apply -f /root/chaos/experiments/test.yaml
kubectl wait --for=condition=Accomplished workflow/resilience-test --timeout=120s
```{{exec}}

A workflow that finishes is not necessarily one that passed; an aborted workflow is also "accomplished". The result is in each node of the workflow, one per template:

```bash
kubectl get workflownodes -l chaos-mesh.org/workflow=resilience-test -o custom-columns='NODE:.metadata.name,TYPE:.spec.type,ABORTED:.status.conditions[?(@.type=="Aborted")].status'
```{{exec}}

> All the nodes ran, including those of the network partition, and none is aborted (`<none>` on the chaos nodes just means the condition is never set there). Both experiments ran, every check held.

Chaos Mesh does not print a verdict, but it does put an abort annotation on the workflow when a check fails, and that is one line away from one:

```bash
[ "$(kubectl get workflow resilience-test -o jsonpath='{.metadata.annotations.workflow\.chaos-mesh\.org/abort}')" = "true" ] && echo "FAILED" || echo "PASSED"
```{{exec}}

> `PASSED`.

### Step 2: Break something and run it again

The checks also tell you when something has regressed. Undo the fix from the first experiment:

```bash
kubectl scale deployment backend --replicas=1
kubectl rollout status deployment backend
```{{exec}}

A workflow runs once, so delete it, and its nodes, and apply it again. (The nodes are cleaned up in the background; if a new workflow with the same name finds the old finished nodes, it considers itself done.)

```bash
kubectl delete -f /root/chaos/experiments/test.yaml
kubectl delete workflownodes -l chaos-mesh.org/workflow=resilience-test
kubectl apply -f /root/chaos/experiments/test.yaml
kubectl wait --for=condition=Accomplished workflow/resilience-test --timeout=120s
kubectl get workflownodes -l chaos-mesh.org/workflow=resilience-test -o custom-columns='NODE:.metadata.name,TYPE:.spec.type,ABORTED:.status.conditions[?(@.type=="Aborted")].status'
[ "$(kubectl get workflow resilience-test -o jsonpath='{.metadata.annotations.workflow\.chaos-mesh\.org/abort}')" = "true" ] && echo "FAILED: a status check did not hold" || echo "PASSED: all status checks held"
```{{exec}}

> `FAILED`, and only the nodes of the first experiment exist, the check among them marked aborted. The pod kill caused downtime again, `products-keep-working` saw it, and the second experiment never ran. Nobody had to run vegeta or read a report.

Put the fix back:

```bash
kubectl scale deployment backend --replicas=2
kubectl rollout status deployment backend
```{{exec}}

## Where this runs

You would normally not run Chaos Mesh from `kubectl`:

- it has a dashboard where workflows are composed, started and watched, which we cannot host in this environment;
- it has a [GitHub Action](https://chaos-mesh.org/docs/integrate-chaos-mesh-into-github-actions/) for running experiments when deploying to staging, though that is not common.

Chaos engineering is not a test suite. Its value is in the experiments you run from time to time, after a big change or before a launch, to find weaknesses you could not find any other way. The experiments live as code next to the manifests they test, reviewed and versioned like everything else. When they run is a choice.
