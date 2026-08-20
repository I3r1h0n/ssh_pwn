#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Network interface enumeration

ip -o -4 addr show 2>/dev/null | awk '{split($4,a,"/"); print "IFACE: "$2" | ADDR: "a[1]" | MASK: /"a[2]}'

exit 0
