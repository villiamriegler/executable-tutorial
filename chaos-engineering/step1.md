# Chaos engineering and Chaos Mesh

## What is chaos engineering?

Chaos engineering is a discipline for finding out how a system behaves under failure by causing the failure on purpose, as a controlled experiment, instead of waiting for it to happen in production. An experiment starts with a hypothesis about what should happen, for example "if one backend pod dies, users do not notice". Then the failure is injected while the system is under realistic load, and what users actually get is measured.

If the measurement contradicts the hypothesis, you have found a weakness that no unit test would have shown you. Once it is fixed, the same experiment confirms the fix. The practice grew out of Netflix randomly killing production servers so that engineers had to build services that tolerate it.

It matters for DevOps teams because the failures it exercises are infrastructure failures, which only show up once the application runs on real infrastructure. A staging cluster is the first place they can be tested at all, and the delivery pipeline is where that test can be made to run on every change.

## What is Chaos Mesh?

[Chaos Mesh](https://chaos-mesh.org/) is an open-source chaos engineering platform for Kubernetes. It runs inside the cluster and injects failures into your workloads, from killing pods to delaying or cutting their network traffic. Every experiment is a Kubernetes resource: you describe the failure in YAML and apply it with `kubectl`, the same way you apply a Deployment, so experiments can be versioned, reviewed and run again.

Under the hood a controller watches for experiment resources and a daemon on every node carries them out, for example by deleting the pod or rewriting the network rules inside the pod's network namespace. Experiments can also be chained into a `Workflow` and run repeatedly on a `Schedule`.

Chaos Mesh is already installed in this cluster, in its own namespace:

```bash
kubectl get pods -n chaos-mesh
```{{exec}}

The experiment types it added to the cluster:

```bash
kubectl api-resources --api-group=chaos-mesh.org
```{{exec}}

You will use `PodChaos` and `NetworkChaos`.

Press **Check** to make sure the environment is ready before moving on.
