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
    local sep="/"   #"_"
    set -- `ls "$dir"/*.[Mm][Pp]3 | egrep "$tracks" | sort -t "$sep" -k 2n`
    if [ "$#" -lt 1 ]; then rm -f "$dir$suffix.wpl"; return; fi
    generate_wpl "$dir practice" "$@" > "$dir$suffix.wpl"
    unix2dos "$dir$suffix.wpl"
}

for who in Abbe bert Kata demo; do
    make_wpl "$who" _all .
    make_wpl "$who" '' 'Eras|LivingLight|Mutate|Reptiles'
done
