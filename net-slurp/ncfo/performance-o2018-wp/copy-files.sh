#!/bin/bash

use_defaults=yes
copy_show_3_mp3=
copy_show_4_mp3=
delete_mp3_dirs=
copy_show_3_video=
copy_show_4_video=
delete_video_dirs=
while true; do
    case "$1" in
	--show-3|--ours)
	    copy_show_3_mp3=yes; copy_show_3_video=yes; use_defaults=; shift ;;
	--show-4)
	    copy_show_4_mp3=yes; copy_show_4_video=yes; use_defaults=; shift ;;
	-d|--delete)
	    delete_mp3_dirs=yes; delete_video_dirs=yes; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

if [ -n "$use_defaults" ]; then
    copy_show_3_mp3=yes
    copy_show_3_video=yes
    copy_show_4_mp3=
    copy_show_4_video=
    delete_mp3_dirs=yes
    delete_video_dirs=yes
fi

show_3_mp3_dir="show 3"
show_4_mp3_dir="show 4"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$show_3_mp3_dir" "../$show_4_mp3_dir"
fi
show_3_video_dir="show 3 video"
show_4_video_dir="show 4 video"
if [ -n "$delete_video_dirs" ]; then
    rm -rf "../$show_3_video_dir" "../$show_4_video_dir"
fi

count_show_3=0
count_show_4=0
./plinks.pl -pt mp3/index.html | \
    while IFS='	' read text url; do
	file="${url##*/}"
	name="${text##Listen to / Watch }"
	name="${name%%, with *}"
	name="${name%% sung by *}"
	name="${name%% - *}"
	name="${name//[\/?:]/_}"
	case "$url" in
	    */Weedpatch_Show3*.mp3)
		if [ -n "$copy_show_3_mp3" ]; then
		    printf -v count_show_3 "%02d" "$(("${count_show_3##0}"+1))"
		    [ -d "../$show_3_mp3_dir" ] || mkdir "../$show_3_mp3_dir"
		    if ! cp -p mp3/"$file" \
			 "../$show_3_mp3_dir/${count_show_3} $name.mp3"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	    */Weedpatch_Show4*.mp3)
		if [ -n "$copy_show_4_mp3" ]; then
		    printf -v count_show_4 "%02d" "$(("${count_show_4##0}"+1))"
		    [ -d "../$show_4_mp3_dir" ] || mkdir "../$show_4_mp3_dir"
		    if ! cp -p mp3/"$file" \
			 "../$show_4_mp3_dir/${count_show_4} $name.mp3"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	    *.mp3)
		echo "Warning: unrecognized file '$file' (skipped)" >&2
		;;
	esac
    done

count_show_3=0
count_show_4=0
./plinks.pl -pt video/index.html | \
    while IFS='	' read text url; do
	file="${url##*/}"
	name="${text##Listen to / Watch }"
	name="${name%%, with *}"
	name="${name%% sung by *}"
	name="${name%% - *}"
	name="${name//[\/?:]/_}"
	case "$url" in
	    */18WP3[-_]*.mp4)
		if [ -n "$copy_show_3_video" ]; then
		    printf -v count_show_3 "%02d" "$(("${count_show_3##0}"+1))"
		    [ -d "../$show_3_video_dir" ] || mkdir "../$show_3_video_dir"
		    if ! cp -p video/"$file" \
			 "../$show_3_video_dir/${count_show_3} $name.mp4"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	    */18WP4[-_]*.mp4)
		if [ -n "$copy_show_4_video" ]; then
		    printf -v count_show_4 "%02d" "$(("${count_show_4##0}"+1))"
		    [ -d "../$show_4_video_dir" ] || mkdir "../$show_4_video_dir"
		    if ! cp -p video/"$file" \
			 "../$show_4_video_dir/${count_show_4} $name.mp4"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	    *.mp4)
		echo "Warning: unrecognized file '$file' (skipped)" >&2
		;;
	esac
    done

performance="`pwd`"
performance="`dirname "$performance"`"
performance="`basename "$performance" | sed -e 's/ performance$//'`"

./playlists.sh -p "$performance (" -s ")"
./id3-tags.sh -a "North Cambridge Family Opera" -p "$performance (" -s ")" -xp
