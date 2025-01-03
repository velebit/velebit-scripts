#!/bin/bash

source "$(dirname "$0")/_uri.sh"

raw_uris=("$chorus_uri" "$solo_uri" "$demo_uri" "$pdf_uri" "$video_uri")
unique_uris=()
while read u; do
    unique_uris+=("$u")
done < <(for u in "${raw_uris[@]}"; do echo "$u"; done | grep . | sort -u)

rm -f check-links.frag.log check-links.log
for uri in "${unique_uris[@]}"; do
    ./log-in.sh
    wget --load-cookies cookies.txt \
	 -P check-links -x -N --restrict-file-names=windows \
	 --wait=1 -nv \
	 "$uri" \
	 2>&1 | tee check-links.frag.log
    cat check-links.frag.log >> check-links.log
    wget --load-cookies cookies.txt \
	 -P check-links -x -N --restrict-file-names=windows \
	 --wait=0.25 -nv --spider \
	 -i "check-links/${uri#http://}" --force-html --base="$uri" \
	 2>&1 | tee check-links.frag.log
    cat check-links.frag.log >> check-links.log
done
rm -f check-links.frag.log

echo ''; echo =====
grep 'unable to resolve' check-links.log
echo --
grep -B1 'ERROR\|broken link!' check-links.log
