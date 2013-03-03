#!/bin/sh

PF_ARGS=
while true; do
    case "$1" in
	-f|--fast)
	    PF_ARGS='--no-gain --no-wipe'; shift ;;
	-*)
	    echo "Unknown flag '$1'!" >&2 ; exit 1 ;;
	*)
	    break ;;
    esac
done

./make-process-list.pl "$@" | ./process-files.pl $PF_ARGS
