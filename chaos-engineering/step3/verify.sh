#!/bin/bash
# Check that the deployed frontend code has a timeout on the backend call, then clean up the experiment.
kubectl get configmap frontend-code -o jsonpath='{.data.app\.py}' | grep -q 'timeout=' || exit 1
kubectl delete -f /root/chaos/experiments/partition.yaml --ignore-not-found > /dev/null
