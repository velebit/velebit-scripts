#!/bin/sh
#node=197
page=Kids_Court_2015_Practice_Materials
file="`basename "$page"`"
type=video
dir=video
log=download-"$type".log
if [ -f "$dir"/index.html ]; then
    rm -f "$dir/$file"; mv "$dir"/index.html "$dir/$file"; fi
cp -p "$dir/$file" "$dir/$file".orig
if ! wget --load-cookies cookies.txt \
    -nd -P "$dir" -N --restrict-file-names=windows \
    --progress=bar:force \
    http://www.familyopera.org/drupal/"$page" \
  > download-index.log 2>&1; then
    cat download-index.log
    rm -f "$dir"/index.html; mv "$dir/$file".orig "$dir"/index.html
    exit 1
fi
cat download-index.log
rm -f "$dir/$file".orig

rm -f "$dir"/index.html; mv "$dir/$file" "$dir"/index.html
./make-url-lists.sh "$dir"/index.html
sed -e 's/	.*//' *."$type".urllist | sort | uniq \
    > "$type"-master.urllist
wget --load-cookies cookies.txt -i "$type"-master.urllist \
    -nd -P "$dir" -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee "$log"
rm -f "$type"-master.urllist
./clean-up.pl "$log"
