#!/bin/sh

cd ..

generate_wpl () {
    local name="$1"; shift

    echo "<?wpl version=\"1.0\"?>"
    echo "<smil>"
    echo "  <head><title>$name</title></head>"
    echo "  <body><seq>"
    for i in "$@"; do
	q="`echo "$i" | sed -e 's/&/&amp;/g'`"
	echo "    <media src=\"$q\"/>"
    done
    echo "  </seq></body>"
    echo "</smil>"
}

make_wpl () {
    local dir="$1"
    local suffix="$2"
    local tracks="$3"
    local ignore="$4"
    if [ -z "$ignore" ]; then ignore='^$'; fi  # cop-out
    local sep="/"   #"_"
    set -- `ls "$dir"/*.[Mm][Pp]3 \
        | egrep "$tracks" | egrep -v "$ignore" | sort -t "$sep" -k 2n`

    if [ "$#" -lt 1 ]; then rm -f "$dir$suffix.wpl"; return; fi
    generate_wpl "$dir practice" "$@" > "$dir$suffix.wpl"
    unix2dos -q "$dir$suffix.wpl"
}

if [ "$#" -eq 0 ]; then set -- Abbe Katarina Meredith; fi
for who in "$@"; do
    rm -f "$who".wpl "$who"_*.wpl
    #make_wpl "$who" '_all' . ''
    #make_wpl "$who" '' \
    #  'Birth|Eras|LivingLight|Mutate|Reptiles|Axolotl|Cetac.ans|4E9|Hedgehog'\
    #  'Piano|Orch'
    #if diff -q "${who}.wpl" "${who}_all.wpl" > /dev/null; then
    #    rm -f "${who}_all.wpl"
    #fi
    make_wpl "$who" '' . ''
    rm -f "${who}_all.wpl"
    #make_wpl "$who" _burn_tmp . 'Piano|Orch'
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
