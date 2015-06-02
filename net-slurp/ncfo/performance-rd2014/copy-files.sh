#!/bin/bash

use_defaults=yes
copy_cast_x_mp3=
copy_cast_y_mp3=
delete_mp3_dirs=
copy_cast_x_video=
copy_cast_y_video=
delete_video_dirs=
while true; do
    case "$1" in
	-x|--cast-x)
	    copy_cast_x_mp3=yes; copy_cast_x_video=yes; use_defaults=; shift ;;
	-y|--cast-y)
	    copy_cast_y_mp3=yes; copy_cast_y_video=yes; use_defaults=; shift ;;
	-xm|--cast-x-mp3)
	    copy_cast_x_mp3=yes; use_defaults=; shift ;;
	-ym|--cast-y-mp3)
	    copy_cast_y_mp3=yes; use_defaults=; shift ;;
	-xv|--cast-x-video)
	    copy_cast_x_video=yes; use_defaults=; shift ;;
	-yv|--cast-y-video)
	    copy_cast_y_video=yes; use_defaults=; shift ;;
	-d|--delete)
	    delete_mp3_dirs=yes; delete_video_dirs=yes; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

if [ -n "$use_defaults" ]; then
    copy_cast_x_mp3=yes
    copy_cast_y_mp3=
    delete_mp3_dirs=yes
    copy_cast_x_video=yes
    copy_cast_y_video=
    delete_video_dirs=yes
fi

cast_x_mp3_dir="cast X"
cast_y_mp3_dir="cast Y"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$cast_x_mp3_dir" "../$cast_y_mp3_dir"
fi
for i in mp3/*; do
    case "$i" in
	*/RainDanceX[-_]*.mp3)
	    if [ -n "$copy_cast_x_mp3" ]; then
		[ -d "../$cast_x_mp3_dir" ] || mkdir "../$cast_x_mp3_dir"
		cp -p "$i" "../$cast_x_mp3_dir"
	    fi ;;
	*/RainDanceY[-_]*.mp3)
	    if [ -n "$copy_cast_y_mp3" ]; then
		[ -d "../$cast_y_mp3_dir" ] || mkdir "../$cast_y_mp3_dir"
		cp -p "$i" "../$cast_y_mp3_dir"
	    fi ;;
	*/index.html)
	    ;;
	*)
	    echo "Warning: unrecognized file '$i' (skipped)" >&2
	    ;;
    esac
done

cast_x_video_dir="cast X video"
cast_y_video_dir="cast Y video"
if [ -n "$delete_video_dirs" ]; then
    rm -rf "../$cast_x_video_dir" "../$cast_y_video_dir"
fi
for i in video/*; do
    case "$i" in
	*/RainDanceX[-_]*.mp4)
	    if [ -n "$copy_cast_x_video" ]; then
		[ -d "../$cast_x_video_dir" ] || mkdir "../$cast_x_video_dir"
		cp -p "$i" "../$cast_x_video_dir"
	    fi ;;
	*/RainDanceY[-_]*.mp4)
	    if [ -n "$copy_cast_y_video" ]; then
		[ -d "../$cast_y_video_dir" ] || mkdir "../$cast_y_video_dir"
		cp -p "$i" "../$cast_y_video_dir"
	    fi ;;
	*/index.html)
	    ;;
	*)
	    echo "Warning: unrecognized file '$i' (skipped)" >&2
	    ;;
    esac
done

performance="`pwd`"
performance="`dirname "$performance"`"
performance="`basename "$performance" | sed -e 's/ performance$//'`"

./playlists.sh -p "$performance (" -s ")"
./id3-tags.sh -a NCFO -p "$performance (" -s ")" -xp
