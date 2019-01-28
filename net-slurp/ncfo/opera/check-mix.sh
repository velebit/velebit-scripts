#!/bin/bash

found=()
links=()
linked=()

while read -r path; do
    found+=("$path")
done < <( find mixed from-midi \
	       -name '*.aup' -o -type d -name '*_data' -prune \
	       -o -type f -print | sort )

while read -r path; do
    links+=("$path")
    linked+=("$(basename "$(readlink "$path")")")
done < <( find mp3-extras.* -type l -print | sort )

in_list () {
    local val="$1"; shift
    local i
    for i in "$@"; do
	if [[ "$i" == "$val" ]]; then
	    return 0
	fi
    done
    false
}

for i in "${links[@]}"; do
    if [ ! -e "$i" ]; then
	echo "Bad link: $i"
    fi
done
for i in "${found[@]}"; do
    if ! in_list "$(basename "$i")" "${linked[@]}"; then
	echo "Unused file: $i"
    fi
done
