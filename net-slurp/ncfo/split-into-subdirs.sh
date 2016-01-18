#!/bin/bash
# Copies files into individual subdirectories with similar names.
# Useful for e.g. looking at practice videos on the Nexus 7 tablet.

# (need bash for "read -d")

top="with-subdirs"
rm -rf "$top"
find . -name "$top" -prune -o -name '*.sh' -o -name '*~' -o -type f -print0 \
| while read -rd $'\0' path; do
    dir="`echo "$path" | sed -e 's!^\./!!;s!/[^/]*$!!'`"
    file="`echo "$path" | sed -e 's!^.*/!!'`"
    subdir="`echo "$file" | sed -e 's!^[0-9][0-9][A-Z][A-Za-z]*-!!' \
                                -e 's!^MIRROR-!!' -e 's!Scene\([0-9]\)!sc\1!' \
                                -e 's!Meas\([0-9]\)!bar\1!' \
                                -e 's!\..*$!!'`"
    mkdir -p "$top/$dir/$subdir"
    cp -p "$path" "$top/$dir/$subdir/$file"
done
