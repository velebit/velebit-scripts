#!/bin/sh
page=2020_Vision_Practice_Page
file="`basename "$page"`"
type=mp3
dir=mp3
log=download-"$type".log
if [ -f "$dir"/index.html ]; then
    rm -f "$dir/$file"; mv "$dir"/index.html "$dir/$file"; fi
cp -p "$dir/$file" "$dir/$file".orig
wget --load-cookies cookies.txt \
    -nd -P "$dir" -N --restrict-file-names=windows \
    -A .mp3,.MP3,"$file",index.html -r -l 1 \
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
