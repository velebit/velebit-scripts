#!/bin/bash

source "$(dirname "$0")/_uri.sh"

type=video
file_dir="$video_dir"
log=download-"$type".log

all_uris=("$video_uri")

for file in "${all_uris[@]##*/}"; do
    if [ -f "$html_dir/$file.html" ]; then
        rm -f "$html_dir/$file"
        mv "$html_dir/$file.html" "$html_dir/$file"
    fi
    cp -p "$html_dir/$file" "$html_dir/$file".orig
done
if ! wget --load-cookies cookies.txt \
    -nd -P "$html_dir" -N --restrict-file-names=windows \
    --progress=bar:force \
    "${all_uris[@]}" \
  > download-index.log 2>&1; then
    cat download-index.log
    for file in "${all_uris[@]##*/}"; do
        rm -f "$html_dir/$file"
        mv "$html_dir/$file".orig "$html_dir/$file.html"
    done
    exit 1
fi
cat download-index.log
for file in "${all_uris[@]##*/}"; do
    rm -f "$html_dir/$file".orig
    rm -f "$html_dir/$file.html"; mv "$html_dir/$file" "$html_dir/$file.html"
done

./make-url-lists.sh --video "$html_dir/${video_uri##*/}.html"
sed -e 's/	.*//' *."$type".urllist | sort | uniq \
    > "$type"-master.urllist
wget --load-cookies cookies.txt -i "$type"-master.urllist \
    -nd -P "$file_dir" -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee "$log"
rm -f "$type"-master.urllist
./clean-up.pl -d "$file_dir" "$log"
