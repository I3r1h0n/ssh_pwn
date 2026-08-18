#!/bin/sh
#
# TAKEN FROM https://github.com/X3r0Day/xero-detect
#
# ssh-keysign-pwn / FD-theft (CVE-2026-46333) checker

# This one works differently from the others. It's not about kernel
# modules or page cache writes. It exploits a race condition in how
# the kernel checks whether a process is "dumpable" (meaning whether
# other processes can poke at it). When a process exits, the kernel
# clears its memory first and closes its file handles second. In that
# tiny window, the dumpable check fails open because there's no memory
# to check anymore, but the file descriptors are still there waiting
# to be stolen. An attacker can use pidfd_getfd to grab those FDs.
#
# The practical targets are ssh-keysign (which opens SSH host private
# keys before dropping privileges) and chage (which opens /etc/shadow).
# Qualys reported this. Linus Torvalds wrote the fix himself on
# May 14 2026. 6 years after Jann Horn first warned about it.
#
# Since there's no specific module to check for, we just look at the
# kernel build date. Before May 14 2026 = vulnerable, after = fixed.

kver=$(uname -r)
vinfo=$(uname -v)

bdate=$(echo "$vinfo" | grep -oE '[A-Z][a-z]{2} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+ [0-9]{4}')
[ -z "$bdate" ] && bdate=$(echo "$vinfo" | grep -oE '[0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+A-Za-z0-9]+')

bts=$(date -d "$bdate" +%s 2>/dev/null)
pts=$(date -d "May 14 2026" +%s)

if [ -z "$bdate" ] || [ -z "$bts" ]; then
    echo "VULNERABLE: kernel $kver (could not determine build date)"
    exit 0
elif [ "$bts" -lt "$pts" ] 2>/dev/null; then
    echo "VULNERABLE: kernel $kver built $bdate (before May 14 2026 fix)"
    exit 0
else
    echo "NOT VULNERABLE: kernel $kver built $bdate (after May 14 2026 fix)"
    exit 1
fi