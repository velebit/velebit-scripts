#!/bin/bash

U2P_MP3_ARGS=()
U2P_VIDEO_ARGS=(-s video/ -d ../video/)

CF_ARGS=(--no-replace-any-prefix --prefix '')

PF_ARGS=()

GAIN_CACHE=(./gain-cache.pl -q -d mp3-gain)

while true; do
    case "$1" in
        -f|--fast)
            PF_ARGS=("${PF_ARGS[@]}" --no-gain --no-wipe)
            GAIN_CACHE=(cat); shift ;;
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

source "$(dirname "$0")/_uri.sh"
html_dir=html
./make-url-lists.sh --wipe \
                    --rebels "$html_dir/${rebels_uri##*/}.html" \
                    --empire "$html_dir/${empire_uri##*/}.html" \
                    --solo "$html_dir/${solo_uri##*/}.html" \
                    --demo "$html_dir/${demo_uri##*/}.html" \
                    --orch "$html_dir/${demo_uri##*/}.html" \
                    --pdf "$html_dir/${pdf_uri##*/}.html"

set -- [^X]*.mp3.urllist
if [ -e .copy-x ]; then set -- "$@" X*.mp3.urllist; fi
./urllist2process.pl "${U2P_MP3_ARGS[@]}" "$@" | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./enumerate.pl | inspect M2e \
    | "${GAIN_CACHE[@]}" | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./globally-uniq.pl --sfdd | inspect M5 \
    | ./playlists-from-process.pl | inspect M6 \
    | ./process-files.pl "${PF_ARGS[@]}"

./urllist2process.pl "${U2P_VIDEO_ARGS[@]}" *.video.urllist | inspect V1 \
    | ./process-files.pl "${PF_ARGS[@]}"

(d="`pwd`"; cd ../video && "$d"/split-into-subdirs.sh)

word_idx="`(./canonicalize-filenames.pl --print-short;echo and_add_1) | wc -w`"
./id3-tags.sh -p "`./canonicalize-filenames.pl -ps` " -tn -xw"$word_idx"
