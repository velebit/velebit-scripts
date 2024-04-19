#!/bin/sh
find . -name raw -prune \
    -o \( -name '*.mp3' -o -name '*.aac' -o -name '*.m4a' \) -print \
    | sed -e 's,/[^/]*$,,' | uniq -c
