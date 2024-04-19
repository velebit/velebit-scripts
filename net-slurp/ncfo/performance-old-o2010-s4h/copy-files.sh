#!/bin/bash

use_defaults=yes
copy_show_8_mp3=
copy_show_7_mp3=
delete_mp3_dirs=
while true; do
    case "$1" in
	-8|--show-8)
	    copy_show_8_mp3=yes; use_defaults=; shift ;;
	-7|--show-7)
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
    copy_show_7_mp3=yes
    delete_mp3_dirs=yes
fi

show_8_mp3_dir="show 8"
show_7_mp3_dir="show 7"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$show_8_mp3_dir" "../$show_7_mp3_dir"
fi
for i in mp3/*; do
    case "$i" in
	*/Haman2010_Show8[-_]*.mp3)
	    if [ -n "$copy_show_8_mp3" ]; then
		[ -d "../$show_8_mp3_dir" ] || mkdir "../$show_8_mp3_dir"
		cp -p "$i" "../$show_8_mp3_dir"
	    fi ;;
	*/Haman2010_Show7[-_]*.mp3)
	    if [ -n "$copy_show_7_mp3" ]; then
		[ -d "../$show_7_mp3_dir" ] || mkdir "../$show_7_mp3_dir"
		cp -p "$i" "../$show_7_mp3_dir"
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
./id3_tags.py -a "North Cambridge Family Opera" -p "$performance (" -s ")" -xp
