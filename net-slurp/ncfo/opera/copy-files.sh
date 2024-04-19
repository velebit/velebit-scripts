#!/bin/bash

U2P_MP3_ARGS=()
U2P_MP3ZIP_ARGS=(-d ../zip/pretty/)
U2P_MP3PEEP_ARGS=(-d ../zip/people/)
U2P_VIDEO_ARGS=(-s video/ -d ../video/)

CF_ARGS=(--no-replace-any-prefix --prefix '')

PF_ARGS=()

ID3_WIPE_ARGS=(--wipe)

#GAIN_CACHE=(./gain-cache.pl -q -d mp3-gain --wipe)

while true; do
    case "$1" in
        -f|--fast)
            PF_ARGS=("${PF_ARGS[@]}" --no-gain --no-wipe)
            ID3_WIPE_ARGS=(--keep)
            shift ;;
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
                    --chorus "$html_dir/${chorus_uri##*/}.html" \
                    --solo "$html_dir/${solo_uri##*/}.html" \
                    --demo "$html_dir/${demo_uri##*/}.html" \
                    --orch "$html_dir/${demo_uri##*/}.html" \
                    --video "$html_dir/${video_uri##*/}.html" \
                    --pdf "$html_dir/${pdf_uri##*/}.html"

shopt -s nullglob
set -- [^X]*.mp3.urllist
if [ -e .copy-x ]; then set -- "$@" X*.mp3.urllist;
elif [ -e .copy-cd ]; then set -- "$@" X-cd-*.mp3.urllist; fi
./urllist2process.pl "${U2P_MP3_ARGS[@]}" "$@" | inspect M1 \
    | ./extras2process.pl mp3-extras.* | inspect M2 \
    | ./enumerate.pl | inspect M2e \
    | ./omit-if-missing.pl | inspect M3 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect M4 \
    | ./globally-uniq.pl --sfdd | inspect M5 \
    | ./playlists-from-process.pl | inspect M6 \
    | ./process-files.py "${PF_ARGS[@]}"

do_id3_zip=
set -- *.mp3zip.urllist
if [ "$#" -gt 0 -a -e "$1" ]; then
    do_id3_zip=yes
    mkdir -p ../zip/pretty
    ./urllist2process.pl "${U2P_MP3ZIP_ARGS[@]}" "$@" | inspect Z1 \
        | ./omit-if-missing.pl | inspect Z3 \
        | ./globally-uniq.pl --sfdd | inspect Z5 \
        | ./playlists-from-process.pl -s '' | inspect Z6 \
        | ./process-files.py "${PF_ARGS[@]}"
fi
set -- *.mp3people.urllist
if [ "$#" -gt 0 -a -e "$1" ]; then
    do_id3_zip=yes
    mkdir -p ../zip/people
    ./urllist2process.pl "${U2P_MP3PEEP_ARGS[@]}" "$@" | inspect P1 \
        | ./omit-if-missing.pl | inspect P3 \
        | ./globally-uniq.pl --sfdd | inspect P5 \
        | ./playlists-from-process.pl -s '' | inspect P6 \
        | ./process-files.py "${PF_ARGS[@]}"
fi

./urllist2process.pl "${U2P_VIDEO_ARGS[@]}" *.video.urllist | inspect V1 \
    | ./process-files.py "${PF_ARGS[@]}"

(d="`pwd`"; cd ../video && "$d"/split-into-subdirs.sh)

word_idx="`(./canonicalize-filenames.pl --print-short;echo and_add_1) | wc -w`"
./id3_tags.py -p "`./canonicalize-filenames.pl -ps` " -tn -xw"$word_idx" \
              "${ID3_WIPE_ARGS[@]}"
if [ -n "$do_id3_zip" ]; then
    ./id3_tags.py -d zip/pretty -p '' -xx -s '' "${ID3_WIPE_ARGS[@]}"
    ./id3_tags.py -d zip/people \
		  -p "`./canonicalize-filenames.pl --print-short` " \
		  -xw"$word_idx" -s " practice" \
		  "${ID3_WIPE_ARGS[@]}"
fi
