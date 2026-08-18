#!/bin/sh
#
# CAREFULLY VIBECODED
#
# PwnKit (CVE-2021-4034) checker

# This is a vulnerability in Polkit's pkexec utility that allows
# an unprivileged user to run commands as root through improper
# argument handling. Affects polkit versions < 0.120.
# CVSS 7.8.

# First check if pkexec is even installed
if ! command -v pkexec >/dev/null 2>&1; then
    echo "NOT VULNERABLE: pkexec not installed"
    exit 1
fi

# Get the polkit version from pkexec --version
# Output looks like "pkexec version 0.105" or similar
version=$(pkexec --version 2>&1)
ver=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+' | head -1)

if [ -z "$ver" ]; then
    echo "VULNERABLE: pkexec installed but could not determine version"
    exit 0
fi

# Split version into components
maj=$(echo "$ver" | cut -d. -f1)
min=$(echo "$ver" | cut -d. -f2)

# Affected versions: polkit < 0.120
# Check if version is less than 0.120
if [ "$maj" -lt 0 ] 2>/dev/null; then
    echo "VULNERABLE: polkit $ver (< 0.120)"
    exit 0
elif [ "$maj" -eq 0 ] 2>/dev/null; then
    if [ "$min" -lt 120 ] 2>/dev/null; then
        echo "VULNERABLE: polkit $ver (< 0.120)"
        exit 0
    else
        echo "NOT VULNERABLE: polkit $ver (>= 0.120, patched)"
        exit 1
    fi
else
    # Major version > 0 means newer than 0.120
    echo "NOT VULNERABLE: polkit $ver (>= 0.120, patched)"
    exit 1
fi