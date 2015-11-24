#!/bin/bash

U2P_MP3_ARGS=()
U2P_VIDEO_ARGS=(-s video/ -d ../video/)

CF_ARGS=(--no-replace-any-prefix --prefix ''
    -r '---.* p(\d+)(?: .*)?$=_pg-$1' -r '---.*$='
    -r '[-_]Practice(?:$|(?=[-_ ]))='
    -r '^(.*?)[-_]WWscene(\d+(?:[-\.](?!8va)\d+)?)[-_]?=scene-$2___$1_'
    -r '^scene-(.*)___(.*)_(pg-\d+)$=scene-$1_$3_$2' -r '___=_'
    -r '^scene-(\d+)-(?!8va)(\d+)=scene-$1.$2'
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
    #tee "log-$1.tmp"
    cat
}

./make-url-lists.sh
./urllist2process.pl "${U2P_MP3_ARGS[@]}" *.mp3.urllist | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./gain-cache.pl | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./playlists-from-process.pl | inspect M5 \
    | ./process-files.pl "${PF_ARGS[@]}"
./urllist2process.pl "${U2P_VIDEO_ARGS[@]}" *.video.urllist | inspect V1 \
    | ./process-files.pl "${PF_ARGS[@]}"
./id3-tags.sh
