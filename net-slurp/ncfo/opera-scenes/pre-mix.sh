#!/bin/bash

source "$(dirname "$0")/_uri.sh"
html_dir=html
./make-url-lists.sh --chorus "$html_dir/${chorus_uri##*/}.html" \
                    --demo "$html_dir/${chorus_uri##*/}.html" \
                    --orch "$html_dir/${chorus_uri##*/}.html"

sources=( tmplists/bith.mp3.tmplist )
for type in so cc est; do
    sources+=( tmplists/"$type"-chorus-?.mp3.tmplist )
done
for source in "${sources[@]}"; do
        #echo "S> '$source'" >&2
        sed -e 's/.*	out_file://;s/^[A-Za-z]* [SATB] //;s,/,_,g' \
            -e 's/^\(SO\|CC\|Est\|SH\) //' \
            -e 's/^\(w \)\?\(Chorus\) \(Soprano\|Alto\|Tenor\|Bass\) //' \
            -e 's/,\? \(Stormtr\?oopers\?\|Aliens\) \(Soprano\|Alto\|Tenor\|Bass\).*//' \
            -e 's/,\? \(Soprano\|Alto\|Tenor\|Bass\)//' \
            -e 's/,\? \(Soprano\|Alto\|Tenor\|Bass\)//' \
            -e 's/\(Bith\) \([1-9]\)/\1/' \
            -e 's/, [1-9][0-9]*-[1-9][0-9]*,.*//' \
            -e 's/,\? \(High\|Low\) \(split\).*//' \
            "$source" \
            | sort | uniq \
            | while read track; do
                  #echo "T> '$track'" >&2
                  #pattern=$(echo "$track" \
                  #              | sed -e 's/ \(bars \)/.* \1/I' )
                  pattern="/[A-Za-z]* \([SATB] \)\?.*$track"
                  #echo "P> '$pattern'" >&2
                  ./urllist2process.pl "$source" \
                      | grep -i "$pattern" \
                      | sed -e 's@=.*/@=mix-sources/'"$track"'/@'
              done
done \
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
