# The system

Two small services run in the cluster. The `frontend` serves a web page with a product table; it gets the products from the `backend`, which serves them as JSON.

![Architecture](./images/architecture.svg)

Both are Deployments with one pod each:

```bash
kubectl get pods
```{{exec}}

Each has a Service. `frontend` is a NodePort, reachable from outside the cluster on port 30080. `backend` is a ClusterIP, only reachable from inside the cluster, by name:

```bash
kubectl get svc
```{{exec}}

Ask the frontend for the page, as a user would:

```bash
curl -s localhost:30080/
```{{exec}}

To build that table, the frontend calls the backend. This is the same call, made from inside the frontend pod:

```bash
kubectl exec deploy/frontend -- wget -qO- http://backend:8080/items
```{{exec}}

In the frontend code (`/root/chaos/frontend/app.py`) that call is one function:

```python
def fetch_items():
    with urllib.request.urlopen(BACKEND) as response:
        return json.load(response)["items"]
```

Keep that line in mind. The experiments are about what happens to the user when the thing on the other end of it is gone.
