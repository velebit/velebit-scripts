#!/bin/bash

./make-url-lists.sh

source=bert.mp3.urllist

sed -e 's/.*	out_file://;s/^[SATB] //;s/ \?- rev .*//I' "$source" \
    | while read track; do
          ./urllist2process.pl X-all-voices.mp3.urllist \
              | fgrep "$track" \
	      | sed -e 's,=.*/,=mix/'"$track"'/,'
      done \
    | ./process-files.pl
