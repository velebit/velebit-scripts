#!/bin/bash

# this should match copy-files:
prefix=(`./canonicalize-filenames.pl --print-short \
         | sed -e 's/^20[0-9][0-9] //'`)
CF_ARGS=(-rf canonical-replacements.txt \
    --no-replace-any-prefix --fallback-prefix "${prefix[0]}"zz_)

inspect() {
    rm -f "log-$1.tmp"
    if [ -e .inspect ]; then
        tee "log-$1.tmp"
    else
        cat
    fi
}


./make-url-lists.sh

set -- tmplists/soprano-all-all.mp3.urllist tmplists/alto-all-all.mp3.urllist \
    tmplists/tenor-adults.mp3.urllist tmplists/bass-adults.mp3.urllist

./urllist2process.pl "$@" | inspect PMa1 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect PMa4 \
    | sed -e 's,.*=,,;s,.*/,,;s/_.*//;/zz$/d;/p$/d' | sort | uniq \
    > tmplists/pre-mix.prefixes.txt
prefixes=()
while read p; do prefixes+=("$p"); done < tmplists/pre-mix.prefixes.txt

for prefix in "${prefixes[@]}"; do
    ## echo "T> '$prefix'" >&2
    pattern="/${prefix}_"
    ## echo "P> '$pattern'" >&2
    ./urllist2process.pl "$@" \
        | ./canonicalize-filenames.pl "${CF_ARGS[@]}" \
        | grep "$pattern" | grep -v '82\.mp3$' \
        | sed -e 's@=.*/@=mix-sources/'"$prefix"'/@' \
        | ./globally-uniq.pl --sfdd \
	> tmplists/pre-mix."$prefix".proc
    files="$(wc -l pre-mix."$prefix".proc | sed -e 's/ .*//')"
    if [ "$files" -gt 1 ]; then
	cat tmplists/pre-mix."$prefix".proc
    fi
done \
    | ./process-files.py
