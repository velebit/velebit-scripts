#!/bin/sh

show_tracks () {
    for arg in "$@"; do
	if [ "$arg" = "-" ]; then
	    cat   # read from stdin
	elif [ -d "$arg" ]; then
	    ls "$arg"/*.[mM][pP]3
	elif [ -f "$arg" ]; then
	    case "$arg" in
		*.mp3|*.MP3)
		    echo "$arg" ;;
		*.m3u|*.M3U)
		    sed -e '/^#/d;s/^[ 	]*//;/^$/d' "$arg" ;;
		*)
		    echo "Unknown file argument '$arg'!" >&2; exit 1 ;;
	    esac
	else
	    echo "Unknown argument '$arg'!" >&2; exit 1
	fi
    done
}

SORT_BY_NUMBER=
SORT_BY_NAME=
while true; do
    case "$1" in
	-s|--sort)
	    SORT_BY_NUMBER=sort; shift ;;
	-S|--sort-name)
	    SORT_BY_NAME=sort; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done
if [ -n "$SORT_BY_NUMBER" -a -n "$SORT_BY_NAME" ]; then
    echo "Error: --sort (-s) and --sort-name (-S) are mutually exclusive!" >&2
    exit 1
fi

show_tracks "$@" \
    | sed -e 's,.*/,,;s/\.mp3$//i' \
    | ${SORT_BY_NUMBER:-cat} \
    | sed -e 's/^\([0-9M][0-9]\)[a-z]_/\1_/;s/^[0-9M][0-9]_//' \
    | ${SORT_BY_NAME:-cat} \
    | cat -n
