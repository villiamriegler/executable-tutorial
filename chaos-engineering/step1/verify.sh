#!/bin/bash
# Environment is up: setup finished, frontend answers, Chaos Mesh daemon is ready.
[ -f /root/.setup-done ] || exit 1
curl -sf localhost:30080/ > /dev/null || exit 1
kubectl -n chaos-mesh rollout status ds/chaos-daemon --timeout=10s > /dev/null || exit 1
