#!/bin/bash
# Compare the lists of all tracks from the current directory and from lo-fi.

canonical_file_list () {
    find . -name '00_playlist*' -o -name '*.jpg' -o -name '*.png' \
         -o -name '*.pdf' -o -name '*.sh' -o -name '*.pl' -o -name '*.py' \
         -o -print | sed -e 's,\.\(m4a\|flac\|mp3\)$,.<audio>,' | sort
}

dir1="."
dir2="$(dirname "$0")"
path1="$(realpath "${dir1}")"
path2="$(realpath "${dir2}")"
if [[ -z "${dir1}" ]]; then
    echo "Error: bad path '${dir1}'" >&2; exit 1
elif [[ -z "${dir2}" ]]; then
    echo "Error: bad path '${dir2}'" >&2; exit 1
elif [[ "${dir1}" == "${dir2}" ]]; then
    echo "Error: running from ${dir2}, should be different from ${dir1}" >&2
    exit 1
elif [[ -z "${path1}" ]]; then
    echo "Error: realpath failed on '${dir1}'" >&2; exit 1
elif [[ -z "${path2}" ]]; then
    echo "Error: realpath failed on '${dir2}'" >&2; exit 1
elif [[ "${path1}" == "${path2}" ]]; then
    echo "Error: ${dir1} and ${dir2} both refer to ${path1}" >&2; exit 1
fi

(cd "${dir1}"; canonical_file_list > /tmp/fl_ours.txt)
(cd "${dir2}"; canonical_file_list > /tmp/fl_lofi.txt)
if [[ -n "$DISPLAY" ]]; then
    meld /tmp/fl_ours.txt /tmp/fl_lofi.txt
else
    diff --color=always -u /tmp/fl_ours.txt /tmp/fl_lofi.txt \
         | less -R
fi
rm -f /tmp/fl_ours.txt /tmp/fl_lofi.txt
