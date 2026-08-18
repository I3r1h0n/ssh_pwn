#!/bin/sh
#
# TAKEN FROM https://github.com/X3r0Day/xero-detect
#
# Fragnesia (CVE-2026-46300) checker

# Fragnesia is another page-cache corruption bug in the same family
# as DirtyFrag. It lives in the ESP-in-TCP code path (espintcp).
# The kernel forgets that a memory fragment is shared when it merges
# network buffers, so when it tries to decrypt ESP data in-place it
# ends up XORing AES-GCM keystream directly into cached file pages.
# Build a lookup table of nonces, write one byte at a time, and you
# can overwrite /usr/bin/su in the page cache to get root.
# Disclosed May 13 2026.
#
# We check if esp4 or esp6 are available on your system. If neither
# exists, Fragnesia can't touch you. If either is present, we check
# your kernel build date against May 13 2026 when the fix landed.

# This function checks if a module is compiled into the kernel
# rather than being a separate loadable file. It looks in the
# usual config file locations.
esp_builtin() {
    grep -q 'CONFIG_INET_ESP=y' /boot/config-$(uname -r) 2>/dev/null && return 0
    grep -q 'CONFIG_INET_ESP=y' /lib/modules/$(uname -r)/config 2>/dev/null && return 0
    zcat /proc/config.gz 2>/dev/null | grep -q 'CONFIG_INET_ESP=y' && return 0
    return 1
}

# Check if esp4 or esp6 exist either as loadable modules or
# compiled straight into the kernel. If neither is around,
# this bug doesn't affect you.
if ! modinfo esp4 >/dev/null 2>&1 && ! modinfo esp6 >/dev/null 2>&1 && ! esp_builtin; then
    echo "NOT VULNERABLE: esp4/esp6 not available on this system"
    exit 0
fi

kver=$(uname -r)
vinfo=$(uname -v)

bdate=$(echo "$vinfo" | grep -oE '[A-Z][a-z]{2} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+ [0-9]{4}')
[ -z "$bdate" ] && bdate=$(echo "$vinfo" | grep -oE '[0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+')

bts=$(date -d "$bdate" +%s 2>/dev/null)
pts=$(date -d "May 13 2026" +%s)

if [ -z "$bdate" ] || [ -z "$bts" ]; then
    echo "VULNERABLE: kernel $kver (could not determine build date from: $vinfo)"
    exit 0
elif [ "$bts" -lt "$pts" ] 2>/dev/null; then
    echo "VULNERABLE: kernel $kver built $bdate (before May 13 2026 patch)"
    exit 0
else
    echo "NOT VULNERABLE: kernel $kver built $bdate (after May 13 2026 patch)"
    exit 1
fi