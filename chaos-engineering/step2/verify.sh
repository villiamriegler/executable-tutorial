#!/bin/bash
# At least two backend pods are running and ready.
[ "$(kubectl get pods -l app=backend --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c true)" -ge 2 ]
