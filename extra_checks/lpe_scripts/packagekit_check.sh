#!/bin/sh
#
# TAKEN FROM https://github.com/X3r0Day/xero-detect
#
# PackageKit (CVE-2026-41651) checker

# This is a TOCTOU race condition in PackageKit's transaction handling.
# An unprivileged user can overwrite transaction flags between
# authorization and execution, letting them install arbitrary packages
# as root without any authentication. Affects PackageKit >= 1.0.2 and
# < 1.3.5. CVSS 8.8.

# First check if PackageKit is even installed. If pkcon is missing,
# PackageKit is almost certainly not on the system.
if ! command -v pkcon >/dev/null 2>&1; then
    echo "NOT VULNERABLE: PackageKit not installed"
    exit 1
fi

# Get the PackageKit version from pkcon.
# Output looks like "PackageKit 1.2.4" or just "1.2.4".
version=$(pkcon --version 2>/dev/null)
ver=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$ver" ]; then
    echo "VULNERABLE: PackageKit installed but could not determine version"
    exit 0
fi

# Split version into components
maj=$(echo "$ver" | cut -d. -f1)
min=$(echo "$ver" | cut -d. -f2)
pat=$(echo "$ver" | cut -d. -f3)

# Anything outside major version 1 is not affected
if [ "$maj" -ne 1 ] 2>/dev/null; then
    echo "NOT VULNERABLE: PackageKit $ver (outside affected range)"
    exit 1
fi

# Minor version outside 0-3 is not affected
if [ "$min" -lt 0 ] || [ "$min" -gt 3 ] 2>/dev/null; then
    echo "NOT VULNERABLE: PackageKit $ver (outside affected range)"
    exit 1
fi

# For 1.0.x, only >= 1.0.2 is affected
if [ "$min" -eq 0 ] && [ "$pat" -lt 2 ] 2>/dev/null; then
    echo "NOT VULNERABLE: PackageKit $ver (< 1.0.2, not affected)"
    exit 1
fi

# For 1.3.x, only < 1.3.5 is affected (1.3.5 has the fix)
if [ "$min" -eq 3 ] && [ "$pat" -ge 5 ] 2>/dev/null; then
    echo "NOT VULNERABLE: PackageKit $ver (>= 1.3.5, patched)"
    exit 1
fi

# Everything else in 1.0.x (>= 1.0.2), 1.1.x, 1.2.x, 1.3.x (< 1.3.5) is vulnerable
echo "VULNERABLE: PackageKit $ver (1.0.2 <= version < 1.3.5)"
exit 0