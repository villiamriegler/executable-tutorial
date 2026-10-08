#!/bin/bash
# The deployed frontend code has a timeout on the backend call.
kubectl get configmap frontend-code -o jsonpath='{.data.app\.py}' | grep -q 'timeout='
