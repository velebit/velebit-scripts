#!/bin/bash

U2P_MP3_ARGS=(--enumerate)
U2P_VIDEO_ARGS=(-s video/ -d ../video/)

CF_ARGS=(--no-replace-any-prefix --prefix '')

PF_ARGS=()

while true; do
    case "$1" in
	-f|--fast)
	    PF_ARGS=("${PF_ARGS[@]}" --no-gain --no-wipe); shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

inspect() {
    rm -f "log-$1.tmp"
    if [ -e .inspect ]; then
	tee "log-$1.tmp"
    else
	cat
    fi
}

./make-url-lists.sh

set -- [^X]*.mp3.urllist
if [ -e .copy-x ]; then set -- "$@" X*.mp3.urllist; fi
./urllist2process.pl "${U2P_MP3_ARGS[@]}" "$@" | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./gain-cache.pl | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./globally-uniq.pl --sfdd | inspect M5 \
    | ./playlists-from-process.pl | inspect M6 \
    | ./process-files.pl "${PF_ARGS[@]}"

./urllist2process.pl "${U2P_VIDEO_ARGS[@]}" *.video.urllist | inspect V1 \
    | ./process-files.pl "${PF_ARGS[@]}"

(d="`pwd`"; cd ../video && "$d"/split-into-subdirs.sh)
./id3-tags.sh -tn
