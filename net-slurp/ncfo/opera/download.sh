#!/bin/bash

source "$(dirname "$0")/_uri.sh"

type=mp3
file_dir="$mp3_dir"
#log=download-"$type".log
log=download.log

labeled_uris=(
    "$chorus_uri" chorus
    "$solo_uri" solo
    "$demo_uri" demo
    "$demo_uri" orch
)
plain_uris=()
mul_args=()
for (( i=0; i<"${#labeled_uris[@]}"; i+=2 )); do
    if [ -n "${labeled_uris[i]}" ]; then
        plain_uris+=( "${labeled_uris[i]}" )
        mul_args+=( "--${labeled_uris[i+1]}"
                    "$html_dir/${labeled_uris[i]##*/}.html" )
    fi
done
unique_uris=()
while read u; do
    unique_uris+=("$u")
done < <(for u in "${plain_uris[@]}"; do echo "$u"; done | sort -u)
if [ "${#unique_uris[@]}" -eq 0 ]; then echo "No URIs!!????" >&2; exit 1; fi

for file in "${unique_uris[@]##*/}"; do
    if [ -f "$html_dir/$file.html" ]; then
        rm -f "$html_dir/$file"
        mv "$html_dir/$file.html" "$html_dir/$file"
    fi
    cp -p "$html_dir/$file" "$html_dir/$file".orig
done
if ! wget --load-cookies cookies.txt \
    -nd -P "$html_dir" -N --restrict-file-names=windows \
    --progress=bar:force \
    "${unique_uris[@]}" \
  > download-index.log 2>&1; then
    cat download-index.log
    for file in "${unique_uris[@]##*/}"; do
        rm -f "$html_dir/$file"
        mv "$html_dir/$file".orig "$html_dir/$file.html"
    done
    exit 1
fi
cat download-index.log
for file in "${unique_uris[@]##*/}"; do
    rm -f "$html_dir/$file".orig
    rm -f "$html_dir/$file.html"; mv "$html_dir/$file" "$html_dir/$file.html"
done

./make-url-lists.sh "${mul_args[@]}"

sed -e 's/	.*//' *."$type"*.urllist | sort | uniq \
    | sed -e '/\.[Mm][Pp]3$/!d' \
    > "$type"-master.urllist
wget --load-cookies cookies.txt -i "$type"-master.urllist \
    -nd -P "$file_dir" -N --restrict-file-names=windows \
    --progress=bar:force \
  2>&1 | tee "$log"
rm -f "$type"-master.urllist
./clean-up.pl -d "$file_dir" "$log"
