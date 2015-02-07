#!/bin/sh
#page=node/175
page=2015_Little_Light_Music_Lyrics_and_Sheet_Music
file="`basename "$page"`"
type=pdf
dir=pdf
log=download-"$type".log
if [ -f "$dir"/index.html ]; then
    rm -f "$dir/$file"; mv "$dir"/index.html "$dir/$file"; fi
cp -p "$dir/$file" "$dir/$file".orig
wget --load-cookies cookies.txt \
    -nd -P "$dir" -N --restrict-file-names=windows \
    -A .pdf,.PDF,"$file" -r -l 1 \
    -R Brochure-2014-09-30.pdf,Booklet-2014-09-30.pdf \
    --progress=bar:force \
    http://www.familyopera.org/drupal/"$page" \
  2>&1 | tee "$log"
if [ -f "$dir/$file" ]; then
    rm -f "$dir"/index.html "$dir/$file".orig
    mv "$dir/$file" "$dir"/index.html
    ./clean-up.pl -i "$file" "$log"
elif [ -f "$dir/$file".orig ]; then
    rm -f "$dir"/index.html "$dir/$file"
    mv "$dir/$file".orig "$dir"/index.html
    echo "(index not downloaded)"
else
    echo "(index not downloaded, original missing)"
fi
