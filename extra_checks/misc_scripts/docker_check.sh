#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Docker Presence and Configuration Checker

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "DOCKER: Not installed"
    exit 1
fi

# Get Docker version
version=$(docker --version 2>/dev/null)
ver=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$ver" ]; then
    echo "DOCKER: Installed but could not determine version"
else
    echo "DOCKER: $ver"
fi

# Check if Docker daemon is running
if docker info >/dev/null 2>&1; then
    echo "DOCKER DAEMON: Running"
else
    echo "DOCKER DAEMON: Not running or permission denied"
    exit 0
fi

# Check if user is in docker group
if groups | grep -q docker; then
    echo ""
    echo "WARNING: Current user is in the 'docker' group (equivalent to root access)"
fi

echo ""
echo "--- DOCKER PRIVILEGE CHECK ---"
# Check for Docker socket access
if [ -S /var/run/docker.sock ] && [ -w /var/run/docker.sock ]; then
    echo "WARNING: User can write to Docker socket (/var/run/docker.sock)"
fi

echo ""
echo "--- RUNNING CONTAINERS ---"
containers=$(docker ps --format "{{.Names}} | {{.Image}}" 2>/dev/null)
if [ -z "$containers" ]; then
    echo "No running containers"
else
    echo "$containers"
fi

exit 0