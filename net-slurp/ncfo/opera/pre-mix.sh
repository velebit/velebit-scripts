#!/bin/bash

source "$(dirname "$0")/_uri.sh"
html_dir=html
./make-url-lists.sh --rebels "$html_dir/${rebels_uri##*/}.html" \
                    --empire "$html_dir/${empire_uri##*/}.html" \
                    --solo "$html_dir/${solo_uri##*/}.html" \
                    --demo "$html_dir/${demo_uri##*/}.html"

for source in X-all-voices.mp3.urllist \
		  Katarina.mp3.urllist bert.mp3.urllist; do
    dir="`echo "$source" | sed -e 's/\..*//;s/^X-//;s/-voices$//'`"
    sed -e 's/.*	out_file://;s/^[SATB] //;s,/,_,g' \
	-e 's/ \?- rev .* \(bars \)/ \1/I;s/ \?- rev .*//I' \
	-e 's/ ([^()]*)//;s/ ([^()]*)//;s/ ([^()]*)//' \
	-e 's/,\? \(high \|low \)\(soprano\|alto\|tenor\|bass\)//I' \
	-e 's/,\? \(soprano\|alto\|tenor\|bass\)\( [12]\)\?//I' \
	-e 's/,\? \(hi\(gh\)\? \|middle \|low \)\?split//I' \
	-e 's/ - .*\(without\|singing\| \).*//I' \
	"$source" \
	| sort | uniq \
	| while read track; do
              ## echo "T> '$track'" >&2
              pattern=$(echo "$track" \
			       | sed -e 's/ \(bars \)/.* \1/I' )
              ## echo "P> '$pattern'" >&2
              ./urllist2process.pl "$source" \
		  | grep -i "$pattern" \
		  | sed -e 's@=.*/@=mix-sources/'"$dir/$track"'/@'
          done \
	| ./process-files.py
done

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
