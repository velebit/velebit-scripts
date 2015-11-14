#!/bin/bash

delete_mp3_dirs=yes

performance="`pwd`"
performance="`dirname "$performance"`"
performance="`basename "$performance" | sed -e 's/ performance$//'`"

mp3_dir="$performance"
if [ -n "$delete_mp3_dirs" ]; then
    rm -rf "../$mp3_dir"
fi

num_matches () {
    for i in "$@"; do echo "$i"; done | grep -v '[*?]' | wc -l
}

for i in mp3/*; do
    j="`echo "$i" | perl -pe 's,.*/,,;s/^(MV2011_)?(\d+)_/\2 /'`"
    case "$j" in
	*Demo*.mp3)
	    ;;
	[0-9][0-9]\ *.mp3)
	    [ -d "../$mp3_dir" ] \
		|| mkdir "../$mp3_dir"
	    cp -p "$i" "../$mp3_dir/$j"
	    ;;
	index.html)
	    ;;
	*)
	    echo "Warning: unrecognized file '$i' (skipped)" >&2
	    ;;
    esac
done

video_dir="video"
rm -rf "../$video_dir"
ln -s "download/video" "../$video_dir"

#XXX
./playlists.sh -p "" -s ""
./id3-tags.sh -a "NCFO Science Festival Chorus" -p "" -s "" -xx
