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
    echo "$1" | sed -e '/^[0-9]/s/^[^ ]*  *//'
}

try_remove_parens_and_after () {
    local pat0="$1"; shift
    local pat1="$(echo "$pat0" | sed -e 's/ *(.*//')"
    if [[ -z "$pat1" ]]; then pat1="$pat0"; fi
    echo "$pat1"
}

voice_regex='\(S\|A\|T\|B\|TB\|M\|AC\)\(\|[12]\|cc\)'

tracks=()
while read track; do
    ## echo "0> '$track'" >&2
    clean_track="$(try_remove_parens_and_after "$(remove_number "$track")")"
    ## echo "c> '$clean_track'" >&2
    for t in "${tracks[@]}"; do
        if [[ "$t" == "$clean_track" ]]; then
            continue 2  # don't add duplicates
        fi
    done
    ## echo "t> '$clean_track'" >&2
    tracks+=("$clean_track")
done < <(sed -e 's/.*	out_file://;s/^'"${voice_regex}"' //;s,/,_,g' \
             -e 's/,.*//' \
             tmplists/*-chorus.mp3.tmplist \
             | sort | uniq)

make_pattern () {
    local track="$1"; shift
    local pattern="[/:]\(${voice_regex} \)\?\([1-9]\.[1-9][0-9]\? \)\?$track"
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
        if [ "($t)" = "($track)" ]; then continue; fi  # efficiency shortcut
        this_pattern="$(make_pattern "$t")"
        if [ -z "$(echo ".../$track" | grep -v -i "$this_pattern")" ]; then
            continue  # don't include antipatterns that fully match the track!
        fi
        antipattern="${antipattern}${antipattern:+\|}${this_pattern}"
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
