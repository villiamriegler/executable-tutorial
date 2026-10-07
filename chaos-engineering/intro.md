# Chaos Engineering: Testing How Your Service Behaves When a Dependency Fails

Pods die and networks fail in every system. Unit and integration tests say nothing about it, because they mock dependencies as healthy. Chaos engineering tests it directly: you state a hypothesis about how the system behaves under a failure, inject that failure into the running system, and measure what users see. If the hypothesis is wrong, you fix the system and run the same experiment again.

In this tutorial you do exactly that on a small Kubernetes system with [Chaos Mesh](https://chaos-mesh.org/): first by killing a pod, then by cutting the network to a dependency, and finally by turning the experiment into a test that runs automatically.

**After this tutorial you can:**

- state a hypothesis about a system's behaviour under failure and measure it from the user's side,
- run pod-kill and network-partition experiments with Chaos Mesh,
- explain why a pod that "comes back" still causes failed requests, and why a missing timeout turns an unreachable dependency into a full outage,
- express a chaos experiment as a test that runs automatically after a deployment.

The environment is being set up in the background. Continue when the terminal says `Setup finished.`
