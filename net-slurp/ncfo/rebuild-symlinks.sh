#!/bin/sh

TOP=/home/bert/scripts/net-slurp/ncfo

find_top_level_symlinks () {
    if [ "$#" -eq 0 ]; then set -- -print; fi
    find . -name . -o -type d -prune -o -type l "$@"
}

get_subdirs () {
    echo `ls -l "$TOP" | sed -e '/^d/!d;s/.* //;s/$/ |/'` -
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
    chorus) subdir=science ;;
    *)      subdir="$1" ;;
esac

if [ -z "$subdir" -o ! \( "$subdir" = "-" -o -d "$TOP/$subdir" \) ]; then
    echo "If guessing is not possible, you must specify an argument!" >&2
    echo "" >&2
    echo "Usage: `basename "$0"` [`get_subdirs`]" >&2
    exit 1
fi

# Remove symlinks in the current directory, but not in subdirectories.
find_top_level_symlinks -print0 | xargs -0 -r rm -f

# Recreate symlinks.
ln -s "$TOP"/*.*[^~] .
[ "$subdir" != "-" ] && \
    ln -s "$TOP"/"$subdir"/*.*[^~] .
ln -s /home/bert/scripts/net-slurp/plinks.pl .
