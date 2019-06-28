#!/bin/sh
# NOTE: this script downloads files from one of the old (pre-Drupal) pages.
page=antiphony2002/index.html
file="`basename "$page"`"
type=mp3
dir=mp3
log=download-"$type".log
if [ -f "$dir"/index.html -a "$file" != index.html ]; then
    rm -f "$dir/$file"; mv "$dir"/index.html "$dir/$file"; fi
cp -p "$dir/$file" "$dir/$file".orig
wget \
    -nH --cut-dirs=3 -P "$dir" -N --restrict-file-names=windows \
    -A .mp3,.MP3,"$file" -r -l 1 \
    --progress=bar:force \
    http://www.familyopera.org/prod/mp3/"$page" \
  2>&1 | tee "$log"
if [ -f "$dir/$file" ]; then
    if [ "$file" != index.html ]; then
	rm -f "$dir"/index.html "$dir/$file".orig
	mv "$dir/$file" "$dir"/index.html
    fi
    ./clean-up.pl -i "$file" "$log"
elif [ -f "$dir/$file".orig ]; then
    if [ "$file" != index.html ]; then
	rm -f "$dir"/index.html "$dir/$file"
    fi
    mv "$dir/$file".orig "$dir"/index.html
    echo "(index not downloaded)"
else
    echo "(index not downloaded, original missing)"
fi
