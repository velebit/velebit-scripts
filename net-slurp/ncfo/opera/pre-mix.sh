#!/bin/bash

source "$(dirname "$0")/_uri.sh"
html_dir=html
./make-url-lists.sh --chorus "$html_dir/${chorus_uri##*/}.html" \
                    --solo "$html_dir/${solo_uri##*/}.html" \
                    --demo "$html_dir/${demo_uri##*/}.html" \
                    --orch "$html_dir/${demo_uri##*/}.html"

for source in tmplists/?-chorus.mp3.tmplist; do
    #dir="`echo "$source" | sed -e 's,.*/,,;s/\..*//;s/^X-//;s/-voices$//'`"
    sed -e 's/.*	out_file://;s/^[SATB] //;s,/,_,g' \
        -e 's/, [1-9][0-9]*-[1-9][0-9]*,.*//' \
        "$source" \
        | sort | uniq \
        | while read track; do
              ## echo "T> '$track'" >&2
              #pattern=$(echo "$track" \
              #              | sed -e 's/ \(bars \)/.* \1/I' )
              pattern="/. $track"
              ## echo "P> '$pattern'" >&2
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
