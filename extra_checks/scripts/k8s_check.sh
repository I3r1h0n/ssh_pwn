#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Kubernetes Presence and Configuration Checker

# Check if we're running in Kubernetes by looking for the service account
# This is the most reliable indicator without requiring kubectl
if [ ! -f /var/run/secrets/kubernetes.io/serviceaccount/token ] && \
   [ ! -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
    echo "KUBERNETES: Not detected (no service account mounted)"
    exit 1
fi

echo "KUBERNETES: Detected (running inside a pod)"

# Try to get namespace from the service account
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/namespace ]; then
    namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null)
    echo "NAMESPACE: $namespace"
else
    echo "NAMESPACE: Unknown"
fi

# Check if kubectl is available
if command -v kubectl >/dev/null 2>&1; then
    kubectl_ver=$(kubectl version --client -o json 2>/dev/null | grep -oE '"gitVersion":"[^"]+"' | cut -d'"' -f4 2>/dev/null)
    if [ -n "$kubectl_ver" ]; then
        echo "KUBECTL: $kubectl_ver"
    else
        echo "KUBECTL: Installed (version unknown)"
    fi
else
    echo "KUBECTL: Not installed"
fi

exit 0