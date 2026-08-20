#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Environment File Finder


DIRS="/home /tmp /var /opt /etc /srv /data /docker /app /apps /root /usr/local /mnt"

for d in $DIRS; do
    [ -d "$d" ] || continue
    find "$d" -type f \( \
        -name ".env" -o \
        -name ".env.*" -o \
        -name "*.env" -o \
        -name ".flaskenv" -o \
        -name ".djangoenv" -o \
        -name "env.local" -o \
        -name "env.development" -o \
        -name "env.production" -o \
        -name "env.staging" -o \
        -name ".env.local" -o \
        -name ".env.development" -o \
        -name ".env.production" -o \
        -name ".env.staging" \
    \) 2>/dev/null
done

exit 0