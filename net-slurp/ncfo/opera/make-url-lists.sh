#!/bin/sh
INDEX="${1-mp3/index.html}"
INDEX_PDF="${2-${INDEX}}"
INDEX_VIDEO="${3-${INDEX}}"

DIR=tmplists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

##### generic prep

satb_section () {
    local section="$1"; shift
    local base="$1"; shift

    echo "... $base ($section)" >&2
    section="`echo "$section" | sed -e 's,/, */ *,'`"

    for voice in 'Soprano' 'Alto' 'Tenor' 'Bass'; do
	short="`echo "$voice" | sed -e 's/^\(.\).*/\1/;y/SATB/satb/'`"
	./extract-column-links.pl -l "$INDEX" "$section" "$voice" \
	    > "$DIR"/"$base-$short.mp3.tmplist"
    done
    ./extract-column-links.pl -l "$INDEX" "$section" '^$' \
	> "$DIR"/"$base-solos.mp3.tmplist"
}

satb_section 'Courtiers/Peacocks' 'peacocks'
satb_section 'Courtiers/Frogs' 'frogs'
satb_section 'Courtiers/Myna Birds' 'mynas'
satb_section 'Weavers/Jackals' 'jackals'
satb_section 'Village Elders/Doves/Wise Teachers' 'elders'
satb_section 'Milkmaids/Washerwomen/Koel-birds' 'koels'
satb_section 'Village Children/Mosquitoes' 'mosquitoes'
satb_section 'Prime Ministers/Brain-fever Birds' 'ministers'
# 'Five Kids'

##### individual parts
echo "... individual parts" >&2

### Katarina (???s soprano high)
# MP3s
sed -e '/^soprano p\(61\|71\|105\) lo	/d;s/^[^	]*	//' \
    "$DIR"/mynas-s.mp3.tmplist > Katarina.mp3.urllist

## unstructured MP3 links following the table...
#./plinks.pl -b -pt -t -tl 1 "$INDEX" \
#    | sed -e '/\.mp3$/I!d' \
#          -e '/^Soprano/!d;s/^[^	]*	//' \
#          -e '/^[^	]*Meerkat/I!d;s/^[^	]*	//' \
#          -e '/[^	]*low/I!d;s/^[^	]*	//' >> Katarina.mp3.urllist
# video
./plinks.pl -h -t "$INDEX_VIDEO" \
    | sed -e '/^[^	]*VIDEO/I!d;s/^[^	]*	//' \
          -e '/^[^	]*chorus/I!d;s/^[^	]*	//' \
    > Katarina.video.urllist

### Abbe and bert (???s tenor)
# MP3s
sed -e 's/^[^	]*	//' \
    "$DIR"/mynas-t.mp3.tmplist > Abbert.mp3.urllist

### Laura and Avery (???s soprano low)
# MP3s
sed -e '/^soprano p\(61\|71\|105\) hi	/d;s/^[^	]*	//' \
    "$DIR"/mynas-s.mp3.tmplist > Lauravery.mp3.urllist

### demo MP3s
if [ -e .generate-demo ]; then
    echo "... demo" >&2
    if [ ! -e big.mp3.tmplist ]; then
	./plinks.pl -h -t "$INDEX" > big.mp3.tmplist
    fi
    cat big.mp3.tmplist \
	| sed -e '/\.mp3$/I!d;/^[^	]*demo/I!d;/complete	/Id;s/.*	//' \
	> demo.mp3.urllist
fi

### orchestra-only MP3s
if [ -e .generate-orchestra ]; then
    echo "... orchestra" >&2
    if [ ! -e big.mp3.tmplist ]; then
	./plinks.pl -h -t "$INDEX" > big.mp3.tmplist
    fi
    cat big.mp3.tmplist \
	| sed -e '/\.mp3$/I!d;/^[^	]*orchestra/I!d;/complete	/Id;s/.*	//' \
	> orchestra.mp3.urllist
fi

### score PDFs
if [ -e .generate-score ]; then
    echo "... score" >&2
    ./plinks.pl "$INDEX_PDF" \
	| sed -e '/\.pdf$/I!d;/Score/!d' > score.pdf.urllist
fi
