#!/bin/bash

source "$(dirname "$0")/_uri.sh"

plain_uris=("$chorus_uri" "$solo_uri")
unique_uris=()
while read u; do
    unique_uris+=("$u")
done < <(for u in "${plain_uris[@]}"; do echo "$u"; done | sort -u)
if [ "${#unique_uris[@]}" -eq 0 ]; then echo "No URIs!!????" >&2; exit 1; fi

rm -f check-cols.frag.log check-cols.log
./log-in.sh
for uri in "${unique_uris[@]}"; do
    wget --load-cookies cookies.txt \
	 -P check-cols -x -N --restrict-file-names=windows \
	 --wait=1 -nv \
	 "$uri" \
	 2>&1 | tee check-cols.frag.log
    cat check-cols.frag.log >> check-cols.log
done
rm -f check-cols.frag.log

fmt='%40s %s\n'

for uri in "${unique_uris[@]}"; do
    ./print-table-links.pl --base "$uri" \
                           --show-bold-or-heading --show-text-at-row 0 \
                           "check-cols/${uri#http://}" \
    | tee /tmp/CLCF \
    | while IFS='	' read -r table col link; do
        voice="${table/ Chorus MP3s/}"; voice="${voice/ and /+}"
        file="$(basename "$link")"
        check_file="${file/KidsCourt/KC}"
        case "$voice:$col:$check_file" in
            # If the URL is marked for this chorus, that's great.
            *:Security:*[Ss]ecurity*.mp3) ;;
            *:Security:*[Gg]uards*.mp3) ;;
            *:Security:*SHG*.mp3) ;;
            *:Security:*GSH*.mp3) ;;
            *:Stage\ Hands:*SH*.mp3) ;;
            *:Audience:*Kids*.mp3) ;;
            *:Jury\ Kids:*Kids*.mp3) ;;
            # Special-case some exceptions.
            *:Security:*Fabulini-SH*.mp3) ;;
            *:Security:*ChooseAJury-SH*.mp3) ;;
            # If the URL is marked for another chorus, that's... less great.
            *:*:*[Ss]ecurity*.mp3|*:*:*[Gg]uards*.mp3)
                printf "$fmt" "Link for $col has wrong chorus:" "$file" ;;
            *:*:*SH*.mp3)
                printf "$fmt" "Link for $col has wrong chorus:" "$file" ;;
            *:*:*Kids*.mp3)
                printf "$fmt" "Link for $col has wrong chorus:" "$file" ;;
            # If the URL has the voice part (and no chorus), that's good.
            Soprano:*:*[Ss]op*.mp3) ;;
            Alto:*:*[Aa]lt*.mp3) ;;
            Tenor+Bass:*:*[Tt]en*.mp3) ;;
            Tenor+Bass:*:*[Bb]ass*.mp3) ;;
            # And if all else fails we'll accept "Chorus" or "Demo".
            *:*:*[Cc]horus*.mp3) ;;
            *:*:*[Dd]emo*.mp3) ;;
            # Special-case some more exceptions.
            Soprano:Security:*Discipline-Tenor*.mp3) ;;
            Alto:Security:*Discipline-Tenor*.mp3) ;;
            Soprano:Security:*StoryDahsHigh*.mp3) ;;
            Alto:Security:*StoryDahsLow*.mp3) ;;
            Tenor+Bass:Security:*StoryDahsHigh*.mp3) ;;
            Tenor+Bass:Security:*StoryDahsLow*.mp3) ;;
            # Otherwise, complain.
            *)
                printf "$fmt" "Unexpected $voice $col link:" "$file" ;;
        esac
    done
done
