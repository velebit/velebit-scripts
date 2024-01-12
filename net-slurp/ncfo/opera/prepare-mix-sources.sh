#!/bin/bash

source "$(dirname "$0")/_uri.sh"
html_dir=html
./make-url-lists.sh --chorus "$html_dir/${chorus_uri##*/}.html" \
                    --solo "$html_dir/${solo_uri##*/}.html" \
                    --demo "$html_dir/${demo_uri##*/}.html" \
                    --orch "$html_dir/${demo_uri##*/}.html"

remove_number () {
    echo "$1" | sed -e '/^[0-9]/s/^[^ ]* //'
}

tracks=()
while read track; do
    nntrack="$(remove_number "$track")"
    for t in "${tracks[@]}"; do
        if [ "x$(remove_number "$t")" = "x$nntrack" ]; then
            continue 2  # don't allow a duplicate even if the num is different
        fi
    done
    tracks+=("$track")
done < <(sed -e 's/.*	out_file://;s/^\(S\|A\|T\|B\|M\) //;s,/,_,g' \
             -e 's/,.*//' \
             tmplists/*-chorus.mp3.tmplist \
             | sort | uniq)

for track in "${tracks[@]}"; do
    ## echo "T> '$track'" >&2
    pattern="$(remove_number "$track")"
    pattern="/\([A-Z][A-Z]\? \)\?\([1-9]\.[1-9][0-9]\? \)\?$pattern"
    ## echo "P> '$pattern'" >&2
    ./urllist2process.pl \
            tmplists/?-chorus.mp3.tmplist tmplists/demo.mp3.tmplist \
        | grep -i "$pattern" \
        | sed -e 's@=.*/@=mix-sources/'"$track"'/@'
done \
    | ./omit-if-missing.pl \
    | ./process-files.py

for d in mix-sources/*/*; do
    if [ -d "$d" -a ! -e "$d/mp3wav" ]; then
        #echo "->- $d/mp3wav"
        cat <<'EOF' > "$d/mp3wav" && chmod a+rx "$d/mp3wav"
#!/bin/sh
ffmpeg=ffmpeg
for i in *.mp3; do
    if [ -f "$i" ]; then
        # run all ffmpeg processes in parallel...
        $ffmpeg -i "$i" "`basename "$i" .mp3`.wav" &
    fi
done
wait
EOF
    fi
done
