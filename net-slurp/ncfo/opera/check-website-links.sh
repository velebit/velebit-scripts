#!/bin/bash

source "$(dirname "$0")/_uri.sh"

# collect all URIs from the full labeled_uris list
raw_uris=()
for (( i=0; i<"${#labeled_uris[@]}"; i+=2 )); do
    if [ -n "${labeled_uris[i]}" ]; then
        raw_uris+=( "${labeled_uris[i]}" )
    fi
done
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
    uri_host_path="${uri#*://}"  # remove https://, http://, etc
    wget --load-cookies cookies.txt \
	 -P check-links -x -N --restrict-file-names=windows \
	 --wait=0.25 -nv --spider \
	 -i "check-links/${uri_host_path}" --force-html --base="$uri" \
	 2>&1 | tee check-links.frag.log
    cat check-links.frag.log >> check-links.log
done
rm -f check-links.frag.log

echo ''; echo =====
grep 'unable to resolve' check-links.log
echo --
grep -B1 'ERROR\|broken link!' check-links.log
