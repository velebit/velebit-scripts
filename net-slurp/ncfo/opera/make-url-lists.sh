#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

DIR=tmplists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

##### generic prep

reset_sections () {
    ecl_args=(-f "$INDEX")
}
reset_sections

add_satb_section () {
    local section="$1"; shift
    local base="$1"; shift

    ecl_args+=(-m "  .   $base ($section)")
    # update section search expression; should happen AFTER defining message!
    section="`echo "$section" | sed -e 's,/, */ *,'`"

    for voice in 'Soprano' 'Alto' 'Tenor' 'Bass'; do
	short="`echo "$voice" | sed -e 's/^\(.\).*/\1/;y/SATB/satb/'`"
	ecl_args+=(-t "$section" -c "$voice" -o "$DIR"/"$base-$short.mp3.tmplist")
    done
    ecl_args+=(-t "$section" -c '^$' -o "$DIR"/"$base-solos.mp3.tmplist")
}

extract_sections () {
    echo "... sections" >&2
    ./extract-column-links.pl -l "${ecl_args[@]}"
    reset_sections
}

add_satb_section 'Courtiers/Peacocks' 'peacocks'
add_satb_section 'Courtiers/Frogs' 'frogs'
add_satb_section 'Courtiers/Myna Birds' 'mynas'
add_satb_section 'Weavers/Jackals' 'jackals'
add_satb_section 'Village Elders/Doves/Wise Teachers' 'elders'
add_satb_section 'Milkmaids/Washerwomen/Koel-birds' 'koels'
add_satb_section 'Village Children/Mosquitoes' 'mosquitoes'
add_satb_section 'Prime Ministers/Brain-fever Birds' 'ministers'
# 'Five Kids'
extract_sections

##### individual parts
echo "... individual parts" >&2

### Katarina (???s soprano high)
# MP3s
sed -e '/^soprano p\(61\|71\|105\) lo	/d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/mynas-s.mp3.tmplist > Katarina.mp3.urllist

## unstructured MP3 links following the table...
#./plinks.pl -b -pt -t -tl 1 "$INDEX" \
#    | sed -e '/\.mp3$/I!d' \
#          -e '/^Soprano/!d;s/^[^	]*	//' \
#          -e '/^[^	]*Meerkat/I!d;s/^[^	]*	//' \
#          -e '/[^	]*low/I!d;s/^[^	]*	//' >> Katarina.mp3.urllist

### Abbe and bert (???s tenor)
# MP3s
sed -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/mynas-t.mp3.tmplist > Abbert.mp3.urllist

### Laura and Avery (???s soprano low)
# MP3s
sed -e '/^soprano p\(61\|71\|105\) hi	/d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/mynas-s.mp3.tmplist > Laura+Avery.mp3.urllist

#####  video
if [ "$INDEX_VIDEO" = "$INDEX" ]; then
    tmplist=big.mp3.tmplist
else
    tmplist=big.video.tmplist
fi
if [ ! -e "$tmplist" ]; then
    echo "... big list" >&2
    ./plinks.pl -h -b -t "$INDEX_VIDEO" > "$tmplist"
fi
echo "... video" >&2
cat "$tmplist" \
    | sed -e '/^[^	]*VIDEO/I!d;/^[^	]*MIRROR/I!d' \
          -e 's/^[^	]*	//;s/^[^	]*	//' \
    > mirror.video.urllist
cat "$tmplist" \
    | sed -e '/^[^	]*VIDEO/I!d;/^[^	]*MIRROR/Id' \
          -e 's/^[^	]*	//;s/^[^	]*	//' \
    > regular.video.urllist

### demo MP3s
if [ -e .generate-demo ]; then
    tmplist=big.mp3.tmplist
    if [ ! -e "$tmplist" ]; then
	echo "... big list" >&2
	./plinks.pl -h -b -t "$INDEX" > "$tmplist"
    fi
    echo "... demo" >&2
    cat "$tmplist" \
	| sed -e '/\.mp3$/I!d;/^[^	]*demo/I!d;/complete	/Id' \
	      -e 's/^[^	]*	//' \
	      -e 's/^\([^	]*\)	\(.*\)$/\2	out_file:\1/' \
	> demo.mp3.urllist
fi

### orchestra-only MP3s
if [ -e .generate-orchestra ]; then
    tmplist=big.mp3.tmplist
    if [ ! -e "$tmplist" ]; then
	echo "... big list" >&2
	./plinks.pl -h -b -t "$INDEX" > "$tmplist"
    fi
    echo "... orchestra" >&2
    cat "$tmplist" \
	| sed -e '/\.mp3$/I!d;/^[^	]*orchestra/I!d;/complete	/Id' \
	      -e 's/^[^	]*	//' \
	      -e 's/^\([^	]*\)	\(.*\)$/\2	out_file:\1/' \
	> orchestra.mp3.urllist
fi

### score PDFs
if [ "$INDEX_PDF" = "$INDEX" ]; then
    tmplist=big.mp3.tmplist
else
    tmplist=big.pdf.tmplist
fi
if [ ! -e "$tmplist" ]; then
    echo "... big list" >&2
    ./plinks.pl -h -b -t "$INDEX_PDF" > "$tmplist"
fi
echo "... score" >&2
./plinks.pl "$INDEX_PDF" \
    | sed  -e 's/^[^	]*	//;s/^[^	]*	//' \
    -e '/\.pdf$/I!d;/LibrettoBook/d' > score.pdf.urllist
