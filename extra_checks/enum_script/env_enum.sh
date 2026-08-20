#!/bin/sh
#
# CAREFULLY VIBECODED
#
# Environment File Finder

find / -type f \( \
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

exit 0