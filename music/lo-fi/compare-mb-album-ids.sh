#!/bin/bash
# Compare MusicBrainz album IDs from the current directory and from lo-fi.

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

script="$(dirname "$(realpath "$0")")/../mb-album-ids"
echo "(Getting IDs from ${dir1}; this may take a little while)" >&2
(cd "${dir1}"; "${script}" > /tmp/mbid_ours.txt)
echo "(Getting IDs from ${dir2}; this may take a little while)" >&2
(cd "${dir2}"; "${script}" > /tmp/mbid_lofi.txt)
if [[ -n "$DISPLAY" ]]; then
    meld /tmp/mbid_ours.txt /tmp/mbid_lofi.txt
else
    diff --color=always -u /tmp/mbid_ours.txt /tmp/mbid_lofi.txt \
         | less -R
fi
rm -f /tmp/mbid_ours.txt /tmp/mbid_lofi.txt
