#!/bin/sh
page=2024_Rain_Dance_Auditions
file="`basename "$page"`"
type=files
dir=files
log=download-"$type".log
if [ -f "$dir"/index.html ]; then
    rm -f "$dir/$file"; mv "$dir"/index.html "$dir/$file"; fi
cp -p "$dir/$file" "$dir/$file".orig
wget --load-cookies cookies.txt \
    -nd -P "$dir" -N --restrict-file-names=windows \
    -r -l 1 -A .mp3,.MP3,.pdf,.PDF,"$file" \
    --reject-regex '^http://www.familyopera.org/drupal/$' \
    --progress=bar:force \
    http://www.familyopera.org/drupal/"$page" \
  2>&1 | tee "$log"
if [ -f "$dir/$file" ]; then
    rm -f "$dir"/index.html "$dir/$file".orig
    mv "$dir/$file" "$dir"/index.html
    #./clean-up.pl -i "$file" -i index.html "$log"
elif [ -f "$dir/$file".orig ]; then
    rm -f "$dir"/index.html "$dir/$file"
    mv "$dir/$file".orig "$dir"/index.html
    echo "(index not downloaded)"
else
    echo "(index not downloaded, original missing)"
fi
