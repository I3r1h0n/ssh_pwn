#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Docker enumeration

if ! command -v docker >/dev/null 2>&1; then
    echo "DOCKER: Not installed"
    exit 0
fi

ver=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "DOCKER: ${ver:-unknown}"

if ! docker info >/dev/null 2>&1; then
    echo "DAEMON: Not running or no access"
    exit 0
fi

echo "DAEMON: Running"

if groups 2>/dev/null | grep -q docker; then
    echo "DOCKER_GROUP: Yes (equivalent to root)"
fi

if [ -S /var/run/docker.sock ] && [ -w /var/run/docker.sock ]; then
    echo "SOCKET_WRITABLE: Yes"
fi

containers=$(docker ps --format "CONTAINER: {{.Names}} | {{.Image}} | {{.Status}}" 2>/dev/null)
if [ -n "$containers" ]; then
    echo "$containers"
else
    echo "CONTAINERS: None running"
fi

exit 0
