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
    local sep="/"   #"_"
    generate_wpl "$dir practice" \
	`ls "$dir"/*.[Mm][Pp]3 | sort -t "$sep" -k 2n` > "$dir.wpl"
    unix2dos "$dir.wpl"
}

make_wpl Abbe
make_wpl bert
make_wpl Kata
make_wpl demo
