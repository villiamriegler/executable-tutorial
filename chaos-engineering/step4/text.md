# Putting it together: the experiments as a test

Both experiments were run by hand: apply the chaos, run vegeta, read the report. Nothing stops the next change from setting `replicas` back to 1 or dropping the timeout, and nobody will rerun the experiments to notice. This step turns them into a test that a machine can run.

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
    - name: pod-dies
      templateType: Parallel
      children:
        - kill-backend-pod
        - products-keep-working
    - name: kill-backend-pod
      templateType: PodChaos
      deadline: 10s
      podChaos:
        action: pod-kill
        mode: one
        selector:
          namespaces:
            - default
          labelSelectors:
            app: backend
    - name: products-keep-working
      templateType: StatusCheck
      deadline: 10s
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

    # Experiment 2: cut the network to the backend; /health must keep answering 200
    # and the product page must answer 502 within a second instead of hanging.
    - name: network-partition
      templateType: Parallel
      children:
        - cut-network
        - health-keeps-working
        - products-fail-fast
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
    - name: health-keeps-working
      templateType: StatusCheck
      deadline: 15s
      abortWithStatusCheck: true
      statusCheck:
        mode: Continuous
        type: HTTP
        duration: 15s
        intervalSeconds: 1
        timeoutSeconds: 1
        failureThreshold: 3
        successThreshold: 1
        http:
          url: http://frontend.default.svc:8080/health
          method: GET
          criteria:
            statusCode: "200"
    - name: products-fail-fast
      templateType: StatusCheck
      deadline: 15s
      abortWithStatusCheck: true
      statusCheck:
        mode: Continuous
        type: HTTP
        duration: 15s
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

`failureThreshold: 3` means three failed probes in a row fail the check, so a single request that happens to be in flight when the pod dies does not fail the test.

### Step 1: Run the test

A workflow starts as soon as it is applied. Apply it and watch it until it finishes (about half a minute, `Ctrl+C` to stop watching):

```bash
kubectl apply -f /root/chaos/experiments/test.yaml
kubectl get workflow resilience-test -w
```{{exec}}

> Both experiments ran, every check passed, and the workflow finished. The system survives both failures.

The checks are resources too, with their results:

```bash
kubectl get statuschecks
```{{exec}}

### Step 2: Break something and run it again

This is what the test is for. Undo the fix from the first experiment:

```bash
kubectl scale deployment backend --replicas=1
kubectl rollout status deployment backend
```{{exec}}

A workflow runs once, so delete it and apply it again:

```bash
kubectl delete -f /root/chaos/experiments/test.yaml
kubectl apply -f /root/chaos/experiments/test.yaml
kubectl get workflow resilience-test -w
```{{exec}}

> The workflow is aborted during the first experiment: `products-keep-working` failed. Nobody had to run vegeta or read a report, the test caught the regression.

Put the fix back:

```bash
kubectl scale deployment backend --replicas=2
kubectl rollout status deployment backend
```{{exec}}

### Step 3: Run it on every deployment

The whole test is one file applied with `kubectl`, so it goes wherever your deployment goes. Two common places:

- **The deploy stage of the CI pipeline.** After the manifests are applied to the staging cluster, the pipeline applies the workflow, waits for it to finish, and fails the stage if it was aborted. A change that removes a replica or a timeout never reaches production. In GitHub Actions that is one more step after the deploy:

  ```yaml
  - name: Resilience test
    run: |
      kubectl delete -f experiments/test.yaml --ignore-not-found
      kubectl apply -f experiments/test.yaml
      kubectl wait --for=condition=Accomplished workflow/resilience-test --timeout=120s
  ```

- **On a schedule.** Chaos Mesh has a `Schedule` resource that runs a workflow on a cron expression, for continuously verifying a staging environment regardless of when deployments happen.

Either way the experiments are versioned next to the manifests they test and run without anyone remembering to.
