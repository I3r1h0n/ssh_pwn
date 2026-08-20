#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Certificate File Finder

find / -type f \( \
    -name "*.pem" -o \
    -name "*.crt" -o \
    -name "*.cer" -o \
    -name "*.der" -o \
    -name "*.pfx" -o \
    -name "*.p12" -o \
    -name "*.p7b" -o \
    -name "*.p7c" -o \
    -name "*.key" -o \
    -name "*.csr" -o \
    -name "*.jks" -o \
    -name "*.keystore" -o \
    -name "*.truststore" \
\) 2>/dev/null

exit 0