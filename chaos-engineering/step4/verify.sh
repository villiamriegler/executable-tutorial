#!/bin/bash
# The test workflow exists and the backend was restored to two replicas.
kubectl get workflow resilience-test > /dev/null 2>&1 || exit 1
[ "$(kubectl get deployment backend -o jsonpath='{.spec.replicas}')" = "2" ]
