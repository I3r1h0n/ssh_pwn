#!/bin/sh
#
# TAKEN FROM https://github.com/X3r0Day/xero-detect
#
# CopyFail (CVE-2026-31431) checker

# So CopyFail is this bug in the kernel crypto interface (AF_ALG)
# that lets someone overwrite 4 bytes of any file that's cached in
# memory. Point it at something like /usr/bin/su and suddenly they
# can run whatever they want as root. It's been around since 2017
# and affects basically every Linux distro out there. CVSS 7.8.
#
# First thing we do is check if the algif_aead module is on your
# system at all. If it isn't, the bug can't reach you and you're
# fine. If it is, we check when your kernel was built. Anything
# before April 29 2026 probably doesn't have the fix yet.

# This just checks if a kernel module exists somewhere on the system.
# It looks in the module database, kernel config files, and whether
# it's currently loaded in memory.
mod_available() {
    modinfo "$1" >/dev/null 2>&1 && return 0
    grep -q "CONFIG_$(echo "$1" | tr 'a-z' 'A-Z')=y" /boot/config-$(uname -r) 2>/dev/null && return 0
    grep -q "CONFIG_$(echo "$1" | tr 'a-z' 'A-Z')=y" /lib/modules/$(uname -r)/config 2>/dev/null && return 0
    zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_$(echo "$1" | tr 'a-z' 'A-Z')=y" && return 0
    grep -q "^$1 " /proc/modules 2>/dev/null && return 0
    return 1
}

if ! mod_available algif_aead; then
    echo "NOT VULNERABLE: algif_aead not available"
    exit 0
fi

# Pull the kernel version and the build date from uname.
# The date can look like "Apr 11 23:16:02 UTC 2026" on Ubuntu or
# "01 May 2026 16:30:13 +0000" on Arch, so we try both patterns.
kver=$(uname -r)
vinfo=$(uname -v)

bdate=$(echo "$vinfo" | grep -oE '[A-Z][a-z]{2} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+ [0-9]{4}')
[ -z "$bdate" ] && bdate=$(echo "$vinfo" | grep -oE '[0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+')

# Turn those dates into numbers so we can compare them.
bts=$(date -d "$bdate" +%s 2>/dev/null)
pts=$(date -d "Apr 29 2026" +%s)

if [ -z "$bdate" ] || [ -z "$bts" ]; then
    echo "VULNERABLE: kernel $kver (could not determine build date)"
    exit 0
elif [ "$bts" -lt "$pts" ] 2>/dev/null; then
    echo "VULNERABLE: kernel $kver built $bdate (before Apr 29 2026 patch)"
    exit 0
else
    echo "NOT VULNERABLE: kernel $kver built $bdate (after Apr 29 2026 patch)"
    exit 1
fi