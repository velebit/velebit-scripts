#!/bin/bash

source "$(dirname "$0")/_uri.sh"

file="`basename "$chorus_uri"`"
type=mp3
dir=mp3
html_dir=html
html_ext=.html
log=download-"$type".log
if [ -f "$html_dir/$file$html_ext" ]; then
    rm -f "$dir/$file"; mv "$html_dir/$file$html_ext" "$dir/$file"; fi
cp -p "$dir/$file" "$dir/$file".orig
wget --load-cookies cookies.txt \
    -nd -P "$dir" -N --restrict-file-names=windows \
     -r -l 1 -A .mp3,.MP3,"$file",index.html \
    --reject-regex '^http://www.familyopera.org/drupal/$' \
    --progress=bar:force \
    "$chorus_uri" \
  2>&1 | tee "$log"
if [ -f "$dir/$file" ]; then
    rm -f "$html_dir/$file$html_ext" "$dir/$file".orig
    mv "$dir/$file" "$html_dir/$file$html_ext"
    ./clean-up.pl -i "$file" -i index.html "$log"
elif [ -f "$dir/$file".orig ]; then
    rm -f "$html_dir/$file$html_ext" "$dir/$file"
    mv "$dir/$file".orig "$html_dir/$file$html_ext"
    echo "(index not downloaded)"
else
    echo "(index not downloaded, original missing)"
fi
