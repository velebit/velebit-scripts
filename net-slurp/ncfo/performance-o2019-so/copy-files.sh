#!/bin/bash

use_defaults=yes
copy_show_8_mp3=
copy_show_7_mp3=
delete_mp3_dirs=
while true; do
    case "$1" in
	--red|--show-8|--ours)
	    copy_show_8_mp3=yes; use_defaults=; shift ;;
	--gold|--show-7)
	    copy_show_7_mp3=yes; use_defaults=; shift ;;
	-d|--delete)
	    delete_mp3_dirs=yes; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

if [ -n "$use_defaults" ]; then
    copy_show_8_mp3=yes
    copy_show_7_mp3=
    delete_mp3_dirs=yes
fi

show_8_mp3_dir="Red cast"
show_7_mp3_dir="Gold cast"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$show_8_mp3_dir" "../$show_7_mp3_dir"
fi
count_show_8=0
count_show_7=0
./plinks.pl -pt mp3/index.html | \
    while IFS='	' read text url; do
	file="${url##*/}"
	name="${text##Listen to }"
	name="${name%%, with *}"
	name="${name%%, sung *}"
	name="${name%% - *}"
	name="${name//[\/?:]/_}"
	case "$url" in
	    */19SO-Show8/*.mp3)
		if [ -n "$copy_show_8_mp3" ]; then
		    printf -v count_show_8 "%02d" "$(("${count_show_8##0}"+1))"
		    [ -d "../$show_8_mp3_dir" ] || mkdir "../$show_8_mp3_dir"
		    if ! cp -p mp3/"$file" \
			 "../$show_8_mp3_dir/${count_show_8} $name.mp3"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	    */19SO-Show7/*.mp3)
		if [ -n "$copy_show_7_mp3" ]; then
		    printf -v count_show_7 "%02d" "$(("${count_show_7##0}"+1))"
		    [ -d "../$show_7_mp3_dir" ] || mkdir "../$show_7_mp3_dir"
		    if ! cp -p mp3/"$file" \
			 "../$show_7_mp3_dir/${count_show_7} $name.mp3"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	    *.mp3)
		echo "Warning: unrecognized file '$file' (skipped)" >&2
		;;
	esac
    done

performance="`pwd`"
performance="`dirname "$performance"`"
performance="`basename "$performance" | sed -e 's/ performance$//'`"

./playlists.sh -p "$performance (" -s ")"
./id3-tags.sh -a "North Cambridge Family Opera" -p "$performance (" -s ")" -xp
