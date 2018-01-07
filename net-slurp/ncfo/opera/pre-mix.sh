#!/bin/bash

./make-url-lists.sh

source=X-all-voices.mp3.urllist

sed -e 's/.*	out_file://;s/^[SATB] //' \
    -e 's/ \?- rev .* \(bars \)/ \1/I;s/ \?- rev .*//I' \
    -e 's/,\? \(high \|low \)\?\(soprano\|alto\|tenor\|bass\)\( [12]\)\?//I' \
    -e 's/,\? \(hi\(gh\)\? \|middle \|low \)\?split//I' \
    -e '/KCCC/Id' \
    "$source" \
    | sort | uniq \
    | while read track; do
          pattern=$(echo "$track" \
              | sed -e 's/ \(bars \)/.* \1/I' )
          ./urllist2process.pl X-all-voices.mp3.urllist \
              | grep -i "$pattern" \
              | sed -e 's@=.*/@=mix-sources/'"$track"'/@'
      done \
    | ./process-files.pl
