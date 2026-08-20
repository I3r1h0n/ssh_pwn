#!/bin/sh
#
# CAREFULLY VIBECODED
#
# User Enumeration and History Checker


for dir in /home/*/; do
    [ -d "$dir" ] || continue
    user=$(basename "$dir")

    if [ -f "$dir.bash_history" ]; then
        lines=$(wc -l < "$dir.bash_history" 2>/dev/null || echo "unreadable")
        echo "USER: $user | BASH_HISTORY: Yes ($lines lines)"
    else
        echo "USER: $user | BASH_HISTORY: No"
    fi
done

exit 0