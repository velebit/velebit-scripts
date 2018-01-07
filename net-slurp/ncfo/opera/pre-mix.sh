#!/bin/bash

./make-url-lists.sh

source=bert.mp3.urllist

sed -e 's/.*	out_file://;s/^[SATB] //' \
    -e 's/ \?- rev .* \(bars \)/ \1/I;s/ \?- rev .*//I' \
    -e 's/,\? \( high\| low\)\?tenor\( [12]\)\?//I' \
    "$source" \
    | sort | uniq \
    | while read track; do
	  pattern=$(echo "$track" \
	      | sed -e 's/ \(bars \)/.* \1/I' )
          ./urllist2process.pl X-all-voices.mp3.urllist \
              | grep -i "$pattern" \
	      | sed -e 's,=.*/,=mix/'"$track"'/,'
      done \
    | ./process-files.pl
