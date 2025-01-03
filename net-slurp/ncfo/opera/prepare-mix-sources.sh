#!/bin/bash

source "$(dirname "$0")/_uri.sh"

labeled_uris=(
    "$chorus_uri" chorus
    "$solo_uri" solo
    "$demo_uri" demo
    "$demo_uri" orch
)
mul_args=()
for (( i=0; i<"${#labeled_uris[@]}"; i+=2 )); do
    if [ -n "${labeled_uris[i]}" ]; then
        mul_args+=( "--${labeled_uris[i+1]}"
                    "$html_dir/${labeled_uris[i]##*/}.html" )
    fi
done

./make-url-lists.sh "${mul_args[@]}"

remove_number () {
    echo "$1" | sed -e '/^[0-9]/s/^[^ ]* //'
}

tracks=()
while read track; do
    echo "0> '$track'" >&2
    nntrack="$(remove_number "$track")"
    for t in "${tracks[@]}"; do
        if [ "x$(remove_number "$t")" = "x$nntrack" ]; then
            continue 2  # don't allow a duplicate even if the num is different
        fi
    done
    tracks+=("$track")
done < <(sed -e 's/.*	out_file://;s/^\(S\|A\|T\|B\|TB\|M\) //;s,/,_,g' \
             -e 's/,.*//' \
             tmplists/*-chorus.mp3.tmplist \
             | sort | uniq)

make_pattern () {
    local track="$1"; shift
    local pattern="$(remove_number "$track")"
    pattern="/\([A-Z][A-Z]\? \)\?\([1-9]\.[1-9][0-9]\? \)\?$pattern"
    echo "$pattern"
}

rm -rf mix-sources
rm -f tmplists/mix-sources.*.proc 2>/dev/null

for track in "${tracks[@]}"; do
    ## echo "T> '$track'" >&2
    qtrack="${track/\\/\\\\}"; qtrack="${qtrack/&/\\\&}"
    ## echo "Q> '$qtrack'" >&2
    pattern="$(make_pattern "$track")"
    ## echo "P> '$pattern'" >&2
    # pattern to strip out anything matching a different track's pattern
    # This prevents "Some Track" from including "Some Track (director's cut)"
    antipattern=
    for t in "${tracks[@]}"; do
        if [ "($t)" = "($track)" ]; then continue; fi
        antipattern="${antipattern}${antipattern:+\|}$(make_pattern "$t")"
    done
    if [ -z "$antipattern" ]; then antipattern="^$"; fi # empty-> match nothing
    ## echo "X> '$antipattern'" >&2
    ./urllist2process.pl \
            tmplists/*-chorus.mp3.tmplist tmplists/demo.mp3.tmplist \
        | grep -i "$pattern" \
        | grep -v -i "$antipattern" \
        `# put files in a track dir under mix-sources:` \
        | sed -e 's@=.*/@=@' -e 's@=@=mix-sources/'"$qtrack"'/@' \
        | tee tmplists/mix-sources."$qtrack".proc \
        `# use original file names (to prevent file duplication):` \
        | sed -e 's@^\(\([^=]*/\)\?\([^/=][^/]*\)\)=\(.*/\).*$@\1=\4\3@'
done \
    | sort | uniq \
    | ./omit-if-missing.pl \
    | grep '=mix-sources/' `# hack: ignore bad replacements` \
    | ./process-files.py

for d in mix-sources/*; do
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
