#!/bin/bash

use_defaults=yes
copy_mp3=
delete_mp3_dirs=
copy_video=
delete_video_dirs=
while true; do
    case "$1" in
	--mp3)
	    copy_mp3=yes; use_defaults=; shift ;;
	--video)
	    copy_video=yes; use_defaults=; shift ;;
	-d|--delete)
	    delete_mp3_dirs=yes; delete_video_dirs=yes; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

if [ -n "$use_defaults" ]; then
    copy_mp3=yes
    copy_video=yes
    delete_mp3_dirs=yes
    delete_video_dirs=yes
fi

mp3_dir="mp3"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$mp3_dir"
fi
video_dir="video"
if [ -n "$delete_video_dirs" ]; then
    rm -rf "../$video_dir"
fi

count=0
./plinks.pl -t -plt mp3/index.html | \
    while IFS='	' read link text url; do
	file="${url##*/}"
	file="${file/17_NeilDe/17P_NeilDe}"
	name="${text%% [-–] *}"
	name="${name%% (*}"
	name="${name//[\/?:]/_}"
	case "${link}:::${url}" in
	    'performance audio':::*.mp3)
		if [ -n "$copy_mp3" ]; then
		    printf -v count "%02d" "$(("${count##0}"+1))"
		    [ -d "../$mp3_dir" ] || mkdir "../$mp3_dir"
		    if ! cp -p mp3/"$file" \
			 "../$mp3_dir/${count} $name.mp3"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	esac
    done

count=0
./plinks.pl -t -plt video/index.html | \
    while IFS='	' read link text url; do
	file="${url##*/}"
	name="${text%% [-–] *}"
	name="${name%% (*}"
	name="${name//[\/?:]/_}"
	case "${link}:::${url}" in
	    'performance video':::*.mp4)
		if [ -n "$copy_video" ]; then
		    printf -v count "%02d" "$(("${count##0}"+1))"
		    [ -d "../$video_dir" ] || mkdir "../$video_dir"
		    if ! cp -p video/"$file" \
			 "../$video_dir/${count} $name.mp4"; then
			echo "Warning: copy failed for $file." >&2
		    fi
		fi ;;
	esac
    done

performance="`pwd`"
performance="`dirname "$performance"`"
performance="`basename "$performance" | sed -e 's/ performance$//'`"

./playlists.sh -p "$performance (" -s ")"
mv ../"$performance ($mp3_dir)".m3u ../"$performance".m3u
mv ../"$performance ($mp3_dir)".wpl ../"$performance".wpl
./id3-tags.sh -a "North Cambridge Family Opera" -p '' -s '' -xx
