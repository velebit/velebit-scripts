#!/bin/bash

PF_ARGS=()
while true; do
    case "$1" in
	-f|--fast)
	    PF_ARGS=('--no-gain --no-wipe'); shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

CF_ARGS=()

inspect() {
    #tee "log-$1.tmp"
    cat
}

./make-url-lists.sh
./urllist2process.pl *.mp3.urllist | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./gain-cache.pl | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./playlists-from-process.pl | inspect M5 \
    | ./process-files.pl "${PF_ARGS[@]}"
./urllist2process.pl -s video/ -d ../video/ *.video.urllist | inspect V1 \
    | ./process-files.pl "${PF_ARGS[@]}"
./id3-tags.sh
