#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Kubernetes checker

detected=""

# service account (inside a pod)
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ] || \
   [ -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
    detected="service_account"
    ns=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null)
fi

# KUBERNETES_SERVICE_HOST env var (set automatically inside pods)
if [ -n "$KUBERNETES_SERVICE_HOST" ]; then
    detected="${detected:+$detected,}env_var"
fi

# kubelet process running
if pgrep -x kubelet >/dev/null 2>&1; then
    detected="${detected:+$detected,}kubelet"
fi

# kubeconfig present
for cfg in "$HOME/.kube/config" "/etc/kubernetes/admin.conf"; do
    if [ -f "$cfg" ]; then
        detected="${detected:+$detected,}kubeconfig($cfg)"
        break
    fi
done

# kubectl available
if command -v kubectl >/dev/null 2>&1; then
    kubectl_ver=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    detected="${detected:+$detected,}kubectl(${kubectl_ver:-unknown})"
fi

# cni config
if [ -d /etc/cni/net.d ] && ls /etc/cni/net.d/*.conf >/dev/null 2>&1; then
    detected="${detected:+$detected,}cni"
fi

if [ -z "$detected" ]; then
    echo "K8S: Not detected"
    exit 0
fi

echo "K8S: Detected ($detected)"
[ -n "$ns" ] && echo "K8S_NAMESPACE: $ns"

exit 0
