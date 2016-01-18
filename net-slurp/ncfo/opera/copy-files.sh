#!/bin/bash

U2P_MP3_ARGS=()
U2P_VIDEO_ARGS=(-s video/ -d ../video/)

CF_ARGS=(--no-replace-any-prefix --prefix ''
    -r '---(.*) p(\d+)(?: .*)?$=_pg-$2'
    -r '---(.*) bar[- ]?(\d+)(?: .*)?$=_bar-$2'
    -r '---.*$='
    -r ' +=_'
    -r '[-_]Practice(?:$|(?=[-_ ]))='
    -r '^(.*?)[-_]WWscene(\d+(?:[-\.](?!8va)\d+)?)[-_]?=scene-$2___$1_'
    -r '^scene-(.*)___(.*)_((pg|bar)-\d+)$=scene-$1_$3_$2' -r '___=_'
    -r '^scene-(\d+)-(?!8va)(\d+)=scene-$1.$2'
    -r '^scene-(\d+)\.(?!8va)(\d+)(.*cascade)=scene-$1.c$2$3'
)

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
./urllist2process.pl "${U2P_MP3_ARGS[@]}" *.mp3.urllist | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./gain-cache.pl | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./globally-uniq.pl --sfdd | inspect M5 \
    | ./playlists-from-process.pl | inspect M6 \
    | ./process-files.pl "${PF_ARGS[@]}"
./urllist2process.pl "${U2P_VIDEO_ARGS[@]}" *.video.urllist | inspect V1 \
    | ./process-files.pl "${PF_ARGS[@]}"
(d="`pwd`"; cd ../video && "$d"/split-into-subdirs.sh)
./id3-tags.sh
