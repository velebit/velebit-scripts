#!/bin/bash

use_defaults=yes
copy_cast_x_mp3=
copy_cast_y_mp3=
delete_mp3_dirs=
while true; do
    case "$1" in
	-x|--cast-x)
	    copy_cast_x_mp3=yes; use_defaults=; shift ;;
	-y|--cast-y)
	    copy_cast_y_mp3=yes; use_defaults=; shift ;;
	--all)
	    copy_cast_x_mp3=yes; copy_cast_y_mp3=yes; use_defaults=; shift ;;
	-d|--delete)
	    delete_mp3_dirs=yes; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

if [ -n "$use_defaults" ]; then
    copy_cast_x_mp3=yes
    copy_cast_y_mp3=yes
    delete_mp3_dirs=yes
fi

cast_x_mp3_dir="cast X"
cast_y_mp3_dir="cast Y"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$cast_x_mp3_dir" "../$cast_y_mp3_dir"
fi
for i in mp3/[xy]/*; do
    case "$i" in
	*/x/*.mp3)
	    if [ -n "$copy_cast_x_mp3" ]; then
		[ -d "../$cast_x_mp3_dir" ] || mkdir "../$cast_x_mp3_dir"
		base="`basename "$i"`"
		outfile="Antiphony2002_castX_$base"
		cp -p "$i" "../$cast_x_mp3_dir/$outfile"
		# look at the other side...
		set -- mp3/y/"${base%%[^0-9_]*}"*
		if [ "$#" -eq 0 -o \( "$#" -eq 1 -a ! -e "$1" \) ]; then
		    echo "Note: using x/$base for y, too." >&2
		    [ -d "../$cast_y_mp3_dir" ] || mkdir "../$cast_y_mp3_dir"
		    outfile="Antiphony2002_castY_$base"
		    cp -p "$i" "../$cast_y_mp3_dir/$outfile"
		fi
	    fi ;;
	*/y/*.mp3)
	    if [ -n "$copy_cast_y_mp3" ]; then
		[ -d "../$cast_y_mp3_dir" ] || mkdir "../$cast_y_mp3_dir"
		base="`basename "$i"`"
		outfile="Antiphony2002_castY_$base"
		cp -p "$i" "../$cast_y_mp3_dir/$outfile"
		# look at the other side...
		set -- mp3/x/"${base%%[^0-9_]*}"*
		if [ "$#" -eq 0 -o \( "$#" -eq 1 -a ! -e "$1" \) ]; then
		    echo "Note: using y/$base for x, too." >&2
		    [ -d "../$cast_x_mp3_dir" ] || mkdir "../$cast_x_mp3_dir"
		    outfile="Antiphony2002_castX_$base"
		    cp -p "$i" "../$cast_x_mp3_dir/$outfile"
		fi
	    fi ;;
#	*/index.html)
#	    ;;
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
