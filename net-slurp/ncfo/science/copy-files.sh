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

prefix=(`./canonicalize-filenames.pl --print-short \
         | sed -e 's/^20[0-9][0-9] //'`)
CF_ARGS=(-rf canonical-replacements.txt \
    --no-replace-any-prefix --fallback-prefix "${prefix[0]}"zz_)

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
./urllist2process.pl "$@" | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./gain-cache.pl -q | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./globally-uniq.pl --sfdd | inspect M5 \
    | ./playlists-from-process.pl --sorted | inspect M6 \
    | ./process-files.py "${PF_ARGS[@]}"

word_idx="`(./canonicalize-filenames.pl --print-short;echo and_add_1) | wc -w`"
./id3_tags.py -p "`./canonicalize-filenames.pl -ps` " -tn -xw"$word_idx" --wipe
