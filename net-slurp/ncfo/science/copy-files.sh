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

CF_ARGS=(-rf canonical-replacements.txt \
    --no-replace-any-prefix --fallback-prefix GoSzz_)

inspect() {
    rm -f "log-$1.tmp"
    if [ -e .inspect ]; then
	tee "log-$1.tmp"
    else
	cat
    fi
}


./make-url-lists.sh
./urllist2process.pl *.mp3.urllist | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./gain-cache.pl | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./process-files.pl "${PF_ARGS[@]}"
./playlists.sh
./id3-tags.sh
