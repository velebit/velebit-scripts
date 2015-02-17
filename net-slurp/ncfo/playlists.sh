#!/bin/sh

SHORT="`./canonicalize-filenames.pl --print-short`"

cd ..

generate_wpl () {
    local name="$1"; shift
    local list="$1"; shift

    echo "<?wpl version=\"1.0\"?>"
    echo "<smil>"
    echo "  <head><title>$name</title></head>"
    echo "  <body><seq>"
    sed -e 's/&/&amp;/g' -e 's,^,    <media src=",;s,$,"/>,' < "$list"
    echo "  </seq></body>"
    echo "</smil>"
}

generate_m3u () {
    local name="$1"; shift
    local list="$1"; shift

    echo "## $name"
    cat "$list"
}

## should match the code in tracklist.sh
sort_tracks () {
    # Sort by file name prefix first, full path in case of ties.
    # Using the separator in the sort is a hack, but it allows us to
    # sort '+' ahead of '0'.
    perl -lne '$o=$_;s,.*/,,;s,[-_].*,,;print "$_\t$o"' \
	| sort -f -s -t+ -k 1,1 -k 2 \
	| sed -e 's/.*	//'
}

make_playlist () {
    local prefix="$1"; shift
    local dir="$1"; shift
    local suffix="$1"; shift
    local tracks="$1"; shift
    local ignore="$1"; shift
    if [ -z "$ignore" ]; then ignore='^$'; fi  # cop-out
    local sep="/"   #"_"
    ls "$dir"/*.[Mm][Pp]3 \
        | egrep "$tracks" | egrep -v "$ignore" | sort_tracks \
	> tracks.tmp
    lines=`wc -l < tracks.tmp`
    if [ "$lines" -lt 1 ]; then
	rm -f "$prefix$dir$suffix".{wpl,m3u}; return
    fi
    generate_wpl "$prefix$dir$suffix" tracks.tmp > "$prefix$dir$suffix.wpl"
    unix2dos -q "$prefix$dir$suffix.wpl"
    generate_m3u "$prefix$dir$suffix" tracks.tmp > "$prefix$dir$suffix.m3u"
    rm -f tracks.tmp
    echo "Generated $prefix$dir$suffix.wpl and $prefix$dir$suffix.m3u"
}

directory_contains_mp3_files () {
    set -- "$1"/*.mp3
    case "$#":"$1" in
	0:*)     return 1 ;;
	1:*\**)  return 1 ;;
        *)       return 0 ;;
    esac
}

# The default is to use all directories that contain MP3 files.
if [ "$#" -eq 0 ]; then
    set --
    for i in *; do
	if [ -d "$i" ] && directory_contains_mp3_files "$i"; then
	    set -- "$@" "$i"
	fi
    done
fi

for who in "$@"; do
    rm -f "$who".{wpl,m3u} "$who"_*.{wpl,m3u}
    #make_playlist '' "$who" '_all' . ''
    #make_playlist '' "$who" '' \
    #  'Birth|Eras|LivingLight|Mutate|Reptiles|Axolotl|Cetac.ans|4E9|Hedgehog'\
    #  'Piano|Orch'
    #if diff -q "${who}.wpl" "${who}_all.wpl" > /dev/null; then
    #    rm -f "${who}_all.wpl"
    #fi
    #if diff -q "${who}.m3u" "${who}_all.m3u" > /dev/null; then
    #    rm -f "${who}_all.m3u"
    #fi
    make_playlist "$SHORT " "$who" " practice" . ''
    rm -f "${who}.wpl" "${who}.m3u"
    rm -f "${who}_all.wpl" "${who}_all.m3u"
    #make_playlist '' "$who" _burn_tmp . 'Piano|Orch'
done

#./download/merge-playlists.pl -k \
#    ./Abbe.wpl ./bert.wpl \
#    > Abbert_burn.wpl
#./download/merge-playlists.pl \
#    ./other/Sue_burn_tmp.wpl ./Kata_burn_tmp.wpl \
#    > Sue_burn.wpl
rm -f *_burn_tmp.wpl */*_burn_tmp.wpl

# the double pass through merge-playlists puts all-voices flavors last
#sort -t / -k 2n -k 1 ./Abbe.wpl ./bert.wpl \
#    | tac | ./download/merge-playlists.pl \
#    | tac | ./download/merge-playlists.pl \
#    > ./Abbe+bert.wpl
