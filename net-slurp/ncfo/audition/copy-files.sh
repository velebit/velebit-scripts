#!/bin/bash

dir=files

if [ ! -e links.lst ]; then
    ~/scripts/net-slurp/plinks.pl -h -pt -t "${dir}"/index.html > links.lst
fi

get_for () {
    local who="$1"; shift
    local tab='	'
    local filter_h filter_pt prefix h pt t url audio
    while [[ "$#" -gt 0 ]]; do
        filter_h="$1"; shift
        filter_pt="$1"; shift
        local prefix="$1"; shift
        if [[ -n "${prefix}" ]]; then
            prefix="${prefix} "
        fi
        while IFS="${tab}" read -r h pt t url; do
            if [[ "$h" == *"${filter_h}"* ]] \
                   && [[ "$pt" == "${filter_pt}"* ]] \
                   && [[ "$url" == *.mp3 ]]; then
                audio="$(basename "$url")"
                echo "${dir}/${audio}=${who}/${prefix}${t}.mp3"
            fi
        done < links.lst
    done
}

generate () {
    #get_for Luka \
    #        'Solo Audition' 'Mezzo' 'L solo A1' \
    #        'Solo Audition' 'Tenor' 'L solo T' \
    #        'Harmony Audition' 'Treble' 'L harm SA'
    get_for Abbe \
            'Solo Audition' 'Mezzo' 'A solo A1' \
            'Solo Audition' 'Tenor' 'A solo A2' \
            'Harmony Audition' 'Treble' 'A harm SA'
    get_for bert \
            'Solo Audition' 'Bass' 'b solo B' \
            'Harmony Audition' 'Tenor' 'b harm T' \
            'Harmony Audition' 'Bass' 'b harm B'
}

ENUM_ARGS=(--keep-existing)
PF_ARGS=()
ID3_WIPE_ARGS=(--wipe)

# rm -rf Luka Abbe bert

generate \
    | ./enumerate.pl "${ENUM_ARGS[@]}" \
    | ./omit-if-missing.pl \
    | ./playlists-from-process.pl \
    | ./process-files.py "${PF_ARGS[@]}"

word_idx="$( (./canonicalize-filenames.pl --print-short;echo and_add_1) | wc -w)"
./id3_tags.py -d audition \
              -p "$(./canonicalize-filenames.pl -ps) " -tn -xw"${word_idx}" \
              "${ID3_WIPE_ARGS[@]}"
