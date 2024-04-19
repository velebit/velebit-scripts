#!/bin/bash

TOP=/home/bert/scripts/net-slurp/ncfo

find_top_level_symlinks () {
    if [ "$#" -eq 0 ]; then set -- -print; fi
    find . -name . -o -type d -prune -o -type l "$@"
}

get_subdirs () {
    ls -l "$TOP" | sed -e '/^d/!d;s/.* //'
}
get_abbrev_subdirs () {
    get_subdirs | sed -e 's/performance.*/performance.../' | uniq
}
show_abbrev_expansion_subdirs () {
    for d in performance; do
	echo "  $d...:" `get_subdirs | sed -e '/^'"$d"'/!d;s/^'"$d"'//'`
    done
}
get_abbrev_subdir_args () {
    echo `get_abbrev_subdirs | sed -e 's/$/ |/'` -
}

if [ $# -lt 1 ]; then
    # guess the subdirectory
    set -- "`find_top_level_symlinks -print0 \
	    | xargs -0 -r -n 1 readlink \
	    | sed -e 's,/[^/]*$,/,;/ncfo/!d;s,.*/ncfo/,,;/^$/d;s,/$,,;/\//d' \
            | uniq`"
    if [ -z "$1" ]; then
	echo "Could not guess link type..." >&2
    else
	echo "Guessed the type as '$1'..." >&2
    fi
fi

case "$1" in
    chorus)
	subdir=science ;;
    auditions)
	subdir=audition ;;
    *)
	subdir="$1" ;;
esac

if [ -z "$subdir" -o ! \( "$subdir" = "-" -o -d "$TOP/$subdir" \) ]; then
    echo "If guessing is not possible, you must specify an argument!" >&2
    echo "" >&2
    echo "Usage: `basename "$0"` [`get_abbrev_subdir_args`]" >&2
    show_abbrev_expansion_subdirs
    exit 1
fi

# Remove symlinks in the current directory, but not in subdirectories.
find_top_level_symlinks -print0 | xargs -0 -r rm -f

# Recreate symlinks.
if [ "$subdir" != "-" ]; then
    # link everything from the subdirectory, if any
    ln -s "$TOP"/"$subdir"/*.*[^~] .
fi
if [ "$subdir" != "audition" ]; then
    # in most cases, link everything from the top level...
    ln -s "$TOP"/*.*[^~] .
    # ...plus plinks from one level up...
    ln -s /home/bert/scripts/net-slurp/plinks.pl .
    # ...and a few things from the music directory.
    ln -s /home/bert/scripts/music/id3wipe .
    ln -s /home/bert/scripts/music/reduce-bitrate.sh .
else
    # fallback: link at least this script from the top level!
    ln -s "$TOP"/"`basename "$0"`" .
fi
