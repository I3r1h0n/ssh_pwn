#!/bin/sh
#
# Infrastructure Secrets Finder

find / -type f \( \
    -name "docker-compose*.yml" -o \
    -name "docker-compose*.yaml" -o \
    -name ".dockercfg" -o \
    -name ".docker/config.json" -o \
    -name "portainer.db" -o \
    -name "portainer.key" -o \
    -name "kubeconfig" -o \
    -name "*.kubeconfig" -o \
    -name "admin.conf" -o \
    -name "vault.json" -o \
    -name "vault.hcl" -o \
    -name ".vault-token" -o \
    -name "vault-token" -o \
    -name "secrets.yml" -o \
    -name "secrets.yaml" -o \
    -name "secrets.json" -o \
    -name "secret.yml" -o \
    -name "secret.yaml" -o \
    -name "secret.json" -o \
    -name "credentials" -o \
    -name "credentials.json" -o \
    -name "credentials.yml" -o \
    -name "credentials.yaml" -o \
    -name "consul.hcl" -o \
    -name "consul.json" -o \
    -name "nomad.hcl" -o \
    -name "terraform.tfstate" -o \
    -name "terraform.tfstate.backup" -o \
    -name "*.tfvars" -o \
    -name "ansible-vault*" -o \
    -name "vault_pass*" -o \
    -name "token.json" -o \
    -name "service-account*.json" -o \
    -name "sa-key*.json" \
\) 2>/dev/null

# Kubernetes secrets mount
find /var/run/secrets -type f 2>/dev/null

# Docker secrets mount
find /run/secrets -type f 2>/dev/null

exit 0