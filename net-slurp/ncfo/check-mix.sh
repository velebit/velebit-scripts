#!/bin/bash

found=()
links=()
linked_files=()
linked_paths=()

while read -r path; do
    found+=("$path")
done < <( find mixed from-midi \
	       -name '*.aup3' -o -type d -name '*_data' -prune \
	       -o -type f -print | sort )

while read -r path; do
    links+=("$path")
    lp="$(readlink "$path")"
    linked_paths+=("$lp")
    linked_files+=("$(basename "$lp")")
done < <( find mp3-extras/* -type l -print | sort )

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
    if ! in_list "$(basename "$i")" "${linked_files[@]}"; then
	for dir in mp3; do
	    if [ -e "$dir/$(basename "$i")" ]; then
		echo "Exists in $dir (likely OK): $i"
		continue 2
	    fi
	done
	echo "Unused file: $i"
    fi
done
for i in "${linked_paths[@]}"; do
    for dir in mp3; do
	file="$(basename "$i")"
	if [ -e "$dir/$file" -a "($dir/$file)" != "($i)" ]; then
	    echo "Linked, but exists in $dir: $file"
	fi
    done
done
