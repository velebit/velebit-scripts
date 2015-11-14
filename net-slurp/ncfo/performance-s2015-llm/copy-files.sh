#!/bin/bash

delete_mp3_dirs=yes

all_recordings_mp3_dir="all"
brd_recordings_mp3_dir="Broad"
pea_recordings_mp3_dir="Peabody"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$all_recordings_mp3_dir" \
	"../$brd_recordings_mp3_dir" "../$pea_recordings_mp3_dir"
fi

num_matches () {
    for i in "$@"; do echo "$i"; done | grep -v '[*?]' | wc -l
}

for i in mp3/*; do
    j="`echo "$i" | perl -pe 's,.*/,,;s/^(LLM)(_.+?)(-\d+)/\1\3\2/'`"
    index="`echo "$j" | sed -e '/^LLM-/!d;s/^LLM-//;s/[-_].*//'`"
    case "$j" in
	*Demo*.mp3)
	    ;;
	LLM-*.mp3)
	    if [ -z "$index" ]; then echo "ERROR in index" >&2; exit 1; fi
	    [ -d "../$all_recordings_mp3_dir" ] \
		|| mkdir "../$all_recordings_mp3_dir"
	    cp -p "$i" "../$all_recordings_mp3_dir/$j"
	    ;;
	index.html)
	    ;;
	*)
	    echo "Warning: unrecognized file '$i' (skipped)" >&2
	    ;;
    esac

    copy_brd=
    copy_pea=
    case "$j" in
	LLM-*_Broad*.mp3)
	    copy_brd=yes
	    if [ "`num_matches mp3/LLM*-"$index"_*.mp3`" -eq 1 ]; then
		copy_pea=yes
	    fi
	    ;;
	LLM-*_Peabody*.mp3)
	    copy_pea=yes
	    if [ "`num_matches mp3/LLM*-"$index"_*.mp3`" -eq 1 ]; then
		copy_brd=yes
	    fi
	    ;;
	LLM-*.mp3)
	    if [ "`num_matches mp3/LLM*-"$index"_*.mp3`" -ne 1 ]; then
		echo "Warning: multiple matches for LLM $index." >&2
	    fi
	    copy_brd=yes
	    copy_pea=yes
	    ;;
	LLM*)
	    echo "Warning: strange file name $j." >&2
	    ;;
    esac

    if [ -n "$copy_brd" ]; then
	[ -d "../$brd_recordings_mp3_dir" ] \
	    || mkdir "../$brd_recordings_mp3_dir"
	cp -p "$i" "../$brd_recordings_mp3_dir/$j"
    fi
    if [ -n "$copy_pea" ]; then
	[ -d "../$pea_recordings_mp3_dir" ] \
	    || mkdir "../$pea_recordings_mp3_dir"
	cp -p "$i" "../$pea_recordings_mp3_dir/$j"
    fi
done

video_dir="video"
rm -rf "../$video_dir"
ln -s "download/video" "../$video_dir"

performance="`pwd`"
performance="`dirname "$performance"`"
performance="`basename "$performance" | sed -e 's/ performance$//'`"

#XXX
./playlists.sh -p "$performance (" -s ")"
./id3-tags.sh -a "NCFO Science Festival Chorus" -p "$performance (" -s ")" -xp
