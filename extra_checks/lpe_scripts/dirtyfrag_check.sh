#!/bin/sh
#
# TAKEN FROM https://github.com/X3r0Day/xero-detect
#
# DirtyFrag (CVE-2026-43284 / CVE-2026-43500) checker

# DirtyFrag is actually two related bugs in the kernel networking
# stack. One abuses the ESP/IPsec decryption path (CVE-2026-43284)
# and the other uses the RxRPC protocol (CVE-2026-43500). Both let
# you scribble arbitrary bytes into the kernel's page cache - the
# in-memory copy of files on disk. Overwrite the right bits of
# /usr/bin/su in the cache and you get root. No race condition
# needed, it just works. Disclosed May 7-8 2026.
#
# We check if any of the vulnerable modules exist (esp4, esp6,
# rxrpc). If none are around, you're safe. If any are present,
# we compare your kernel build date against May 8 2026 when the
# patches came out.

mod_available() {
    modinfo "$1" >/dev/null 2>&1 && return 0
    grep -q "CONFIG_$(echo "$1" | tr 'a-z' 'A-Z')=y" /boot/config-$(uname -r) 2>/dev/null && return 0
    grep -q "CONFIG_$(echo "$1" | tr 'a-z' 'A-Z')=y" /lib/modules/$(uname -r)/config 2>/dev/null && return 0
    zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_$(echo "$1" | tr 'a-z' 'A-Z')=y" && return 0
    return 1
}

# The exploit needs at least one of these three modules.
if ! mod_available esp4 && ! mod_available esp6 && ! mod_available rxrpc; then
    echo "NOT VULNERABLE: esp4/esp6/rxrpc not available"
    exit 0
fi

kver=$(uname -r)
vinfo=$(uname -v)

bdate=$(echo "$vinfo" | grep -oE '[A-Z][a-z]{2} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+ [0-9]{4}')
[ -z "$bdate" ] && bdate=$(echo "$vinfo" | grep -oE '[0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+')

bts=$(date -d "$bdate" +%s 2>/dev/null)
pts=$(date -d "May 8 2026" +%s)

if [ -z "$bdate" ] || [ -z "$bts" ]; then
    echo "VULNERABLE: kernel $kver (could not determine build date)"
    exit 0
elif [ "$bts" -lt "$pts" ] 2>/dev/null; then
    echo "VULNERABLE: kernel $kver built $bdate (before May 8 2026 patch)"
    exit 0
else
    echo "NOT VULNERABLE: kernel $kver built $bdate (after May 8 2026 patch)"
    exit 1
fi