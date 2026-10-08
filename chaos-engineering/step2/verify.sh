#!/bin/bash
# Check that at least two backend pods are running and ready, then clean up the experiment.
[ "$(kubectl get pods -l app=backend --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c true)" -ge 2 ] || exit 1
kubectl delete -f /root/chaos/experiments/pod-kill.yaml --ignore-not-found > /dev/null
