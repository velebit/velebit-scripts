#!/bin/bash

source "$(dirname "$0")/_uri.sh"
all_uris=("$chorus_uri" "$solo_uri")

rm -f check-cols.frag.log check-cols.log
./log-in.sh
for uri in "${all_uris[@]}"; do
    wget --load-cookies cookies.txt \
	 -P check-cols -x -N --restrict-file-names=windows \
	 --wait=1 -nv \
	 "$uri" \
	 2>&1 | tee check-cols.frag.log
    cat check-cols.frag.log >> check-cols.log
done
rm -f check-cols.frag.log

fmt='%30s %s\n'

for uri in "${all_uris[@]}"; do
    ./print-table-links.pl -nc --base "$uri" "check-cols/${uri#http://}" \
    | while read -r col link; do
        file="$(basename "$link")"
        case "$col:$file" in
            [01]:*[-_]demo.mp3|[01]:*[-_]demo[-_]*.mp3) ;;
            [01]:*)
                printf "$fmt" 'Unexpected DEMO link:' "$file" ;;
            2:*[-_]demo.mp3|2:*[-_]demo[-_]*.mp3)
                printf "$fmt" 'Unexpected PASSAGE link:' "$file" ;;
	    2:*[-_]pan.mp3|2:*[-_]pan[-_]*.mp3)
                printf "$fmt" 'Unexpected PASSAGE link:' "$file" ;;
	    2:*[-_]panned.mp3|2:*[-_]panned[-_]*.mp3)
                printf "$fmt" 'Unexpected PASSAGE link:' "$file" ;;
            2:*.mp3) ;;
            2:*)
                printf "$fmt" 'Unexpected PASSAGE link:' "$file" ;;
	    3:CC_prologue-piano.mp3|3:CC_prologue-piano-*.mp3) ;; # hello Piper
	    3:*PipersMonologue-piano.mp3|3:*PipersMonologue-piano-*.mp3) ;;
            3:*[-_]pan.mp3|3:*[-_]pan[-_]*.mp3) ;;
            3:*[-_]panned.mp3|3:*[-_]panned[-_]*.mp3) ;;
            3:*)
                printf "$fmt" 'Unexpected PANNED link:' "$file" ;;
            *)
                printf "$fmt" 'Unexpected column:' "$col, for $file" ;;
        esac
    done
done
