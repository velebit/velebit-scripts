#!/bin/sh

case "$1" in
    opera)
	subdir=opera ;;
    science|chorus)
	subdir=science ;;
    *)
	echo "Usage: `basename "$0"` {opera | science}" >&2
	exit 1 ;;
esac

# Remove symlinks in the current directory, but not in subdirectories.
find * -type d -prune -o -type l -print0 | xargs -0 -r rm -f

# Recreate symlinks.
ln -s /home/bert/scripts/net-slurp/ncfo{,/$subdir}/*.*[^~] .
