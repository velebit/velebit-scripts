#!/bin/sh

if [ $# -lt 1 ]; then
    # guess the subdirectory
    set -- "`find * -type d -prune -o -type l -print0 \
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
    opera)
	subdir=opera ;;
    science|chorus)
	subdir=science ;;
    *)
	echo "If guessing is not possible, you must specify an argument!" >&2
	echo "" >&2
	echo "Usage: `basename "$0"` [opera | science]" >&2
	exit 1 ;;
esac

# Remove symlinks in the current directory, but not in subdirectories.
find * -type d -prune -o -type l -print0 | xargs -0 -r rm -f

# Recreate symlinks.
ln -s /home/bert/scripts/net-slurp/ncfo{,/$subdir}/*.*[^~] .
ln -s /home/bert/scripts/net-slurp/plinks.pl .
