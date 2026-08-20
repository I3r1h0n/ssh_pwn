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
        hist="BASH_HISTORY: Yes ($lines lines)"
    else
        hist="BASH_HISTORY: No"
    fi

    last_login=$(lastlog -u "$user" 2>/dev/null | tail -1)
    if echo "$last_login" | grep -q "Never logged in"; then
        login="LAST_LOGIN: Never"
    elif [ -n "$last_login" ]; then
        login="LAST_LOGIN: $(echo "$last_login" | awk '{$1=""; sub(/^ +/,""); print}')"
    else
        login="LAST_LOGIN: N/A"
    fi

    echo "USER: $user | $hist | $login"
done

exit 0