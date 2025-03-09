#!/bin/bash
# may be specific to how I did mixing in 2024-2025

if [ ! -d mixed ]; then
    echo "No 'mixed' directory, are you in the right place?" >&2
    exit 1
fi

ls --quoting-style=literal mixed/*.aup3 \
    | sed \
          -e 's,^.*/,,;s,\..*$,,' \
    | sort -k 2 -k 1,1 | uniq -c > /tmp/FA

ls --quoting-style=literal mixed/*.mp3 \
    | sed \
          -e 's,^.*/,,;s,\..*$,,' \
          -e 's,^unused ,,;s,^T[a-z][a-z][a-z]*[0-9]* ,,;s,^cut ,,' \
    | sort -k 2 -k 1,1 | uniq -c > /tmp/FM

while read -r dir count rest; do
    case "$dir:$count" in
        -:1)    printf "%3d %-16s  %s\n" "$count" '.aup3 file for:' "$rest" ;;
        -:*)    printf "%3d %-16s  %s\n" "$count" '.aup3 files for:' "$rest" ;;
        +:1)    printf "%3d %-16s  %s\n" "$count" '.mp3 file for:' "$rest" ;;
        +:*)    printf "%3d %-16s  %s\n" "$count" '.mp3 files for:' "$rest" ;;
    esac
done < <(diff -L '.aup files' -L '.mp3 files' -sU0 /tmp/F{A,M})
