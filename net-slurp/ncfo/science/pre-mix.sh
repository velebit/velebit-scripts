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

longest_common_prefix() {
    sed -e '1h;G;s/^\(.*\).*\n\1.*$/\1/;h' \
        | tail -1
}


./make-url-lists.sh

set -- tmplists/soprano-all-all.mp3.urllist tmplists/alto-all-all.mp3.urllist \
    tmplists/tenor-adults.mp3.urllist tmplists/bass-adults.mp3.urllist

./urllist2process.pl "$@" | inspect PMa1 \
    | ./canonicalize-filenames.pl "${CF_ARGS[@]}" | inspect PMa4 \
    | sed -e '\,=\([^/]*/\)*[^/_]*\(zz\|p\)[^/]*$,d;/82\.mp3$/d' \
    > tmplists/pre-mix.input.proc
cat tmplists/pre-mix.input.proc \
    | sed -e 's,.*=,,;s,.*/,,' | sort | uniq \
    > tmplists/pre-mix.filenames.txt
prefixes=()
for short_repeated_prefix in \
    $(cat tmplists/pre-mix.filenames.txt \
          | sed -e 's/_.*/_/' | uniq -c \
          | sed -e '/^ *1 /d;s/^ *[1-9][0-9]*  *//')
do
    prefixes+=("$(cat tmplists/pre-mix.filenames.txt \
                     | sed -e 's/^/^^^/' \
                     | fgrep "^^^$short_repeated_prefix" \
                     | sed -e 's/^\^\^\^//' \
                     | longest_common_prefix \
                     | sed -e 's/[-_]$//;s/-final$//')")
done

for prefix in "${prefixes[@]}"; do
    cat tmplists/pre-mix.input.proc \
        | fgrep "/$prefix" \
        | sed -e 's@=.*/@=mix-sources/'"$prefix"'/@' \
        | ./globally-uniq.pl --sfdd \
        | inspect PM."$prefix"
done \
    | ./process-files.py
