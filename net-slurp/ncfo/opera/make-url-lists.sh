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

add_section_column () {
    local section="$1"; shift
    local column="$1"; shift
    local name="$1"; shift
    local flags_on="$1"; shift
    local flags_off="$1"; shift

    ecl_args+=(-m "  .   $name ($section)" $flags_on)
    # update section search expression; should happen AFTER defining message!
    section="`echo "$section" | sed -e 's, ?\([/&]\) ?, *\1 *,'`"

    ecl_args+=(-t "$section" -c "$column" -o "$DIR"/"$name.mp3.tmplist" \
	$flags_off)
}

add_satb_section () {
    local section="$1"; shift
    local base="$1"; shift
    local flags_on="$1"; shift
    local flags_off="$1"; shift

    ecl_args+=(-m "  .   $base ($section)" $flags_on)
    # update section search expression; should happen AFTER defining message!
    section="`echo "$section" | sed -e 's,\([/&]\), *\1 *,'`"

    for voice in 'Soprano' 'Alto' 'Tenor' 'Bass'; do
	short="`echo "$voice" | sed -e 's/^\(.\).*/\1/;y/SATB/satb/'`"
	ecl_args+=(-t "$section" -c "$voice" -o "$DIR"/"$base-$short.mp3.tmplist")
    done
    ecl_args+=(-t "$section" -c '^$' -o "$DIR"/"$base-solos.mp3.tmplist" \
	$flags_off)
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
add_satb_section 'Farmers/Washerwomen/Koel-birds' 'koels'
add_satb_section 'Village Children/Mosquitoes' 'mosquitoes'
add_satb_section 'Prime Ministers/Brain-fever Birds' 'ministers' \
    '--row-line --line-text' '--no-row-line --no-line-text'
add_section_column 'Five Kids' 'Steve & Nina' 'kids-steve-nina'
add_section_column 'Five Kids' 'Carla' 'kids-carla'
add_section_column 'Five Kids' 'Laura' 'kids-laura'
add_section_column 'Five Kids' 'Sam' 'kids-sam'
extract_sections

##### individual parts
echo "... individual parts" >&2

for i in s a t b; do
    cat "$DIR"/ministers-"$i".mp3.tmplist | sed \
	-e 's/$/	out_file_suffix:---/' \
	-e 's/^\(\([^	]* \)\?\(bar \?[1-9][^	]*\)	\([^	]*\)	\([^	]*\)	.*	out_file_suffix:---\)$/\1\2\5 \3/' \
	-e 's/^\([^	]*\)	//' \
	-e 's/^\(page \([1-9][0-9]*\).*	out_file_suffix:---\)$/\1PMs p\2/' \
	-e 's/^\([^	]*\)	//' \
	-e 's/^\(\([^	]*\)	.*	out_file_suffix:---\)$/\1\2/' \
	-e 's/	out_file_suffix:---$//' \
	> "$DIR"/ministers-"$i".cooked.mp3.tmplist
done

### Katarina (PMs soprano high)
# MP3s
cat "$DIR"/ministers-s.cooked.mp3.tmplist | sed \
    -e '/scene9-2/,$d' \
    -e '/^soprano p\(61\|71\|82\|105\) lo	/d' \
    -e '/^\(\(middle\|low\) split\|bass\)	.*PM.*scene8[-_]/d' \
    -e '/^\(\|D\|D\^[^X]\)PM	.*scene8[-_].*bar799/d' \
    -e '/^\(\|D\|D\^[^X]\)PM	.*scene8[-_].*bar807/d' \
    -e '/^\(\|D\|D\^[^X]\)PM	.*scene8[-_].*bar839/d' \
    -e 's/^\([^	]*\)	//' \
    > Katarina.mp3.urllist
cat "$DIR"/elders-s.mp3.tmplist | sed \
    -e '/^doves.*scene9[-_]/!d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    >> Katarina.mp3.urllist
cat "$DIR"/ministers-s.cooked.mp3.tmplist | sed \
    -e '/scene9-2/,$!d' \
    -e '/^soprano p\(61\|71\|82\|105\) lo	/d' \
    -e '/^\(\(middle\|low\) split\|tenor\)	.*PM.*scene11[-_]/d' \
    -e '/^\(middle\|low\) split	.*PM.*scene15[-_]/d' \
    -e '/^\(\|D\|D\^[^6]\)PM	.*scene15[-_].*bar1785/d' \
    -e '/^\(\|D\|D\^[^X]\)PM	.*scene15[-_].*bar1818/d' \
    -e '/^\(\|D\|D\^[^6]\)PM	.*scene15[-_].*bar1830/d' \
    -e 's/^\([^	]*\)	//' \
    >> Katarina.mp3.urllist

## unstructured MP3 links following the table...
#./plinks.pl -b -pt -t -tl 1 "$INDEX" \
#    | sed -e '/\.mp3$/I!d' \
#          -e '/^Soprano/!d;s/^[^	]*	//' \
#          -e '/^[^	]*Meerkat/I!d;s/^[^	]*	//' \
#          -e '/[^	]*low/I!d;s/^[^	]*	//' >> Katarina.mp3.urllist

### Abbe and bert (PMs tenor)
# MP3s: common
cat "$DIR"/ministers-t.cooked.mp3.tmplist | sed \
    -e '/PM.*scene8[-_]/d' \
    -e '/^\(high\|middle\|low\) split	.*PM.*scene11[-_]/d' \
    -e '/PM.*scene15[-_]/d' \
    -e 's/^\([^	]*\)	//' \
    > Abbe+bert.mp3.urllist

# MP3s: Abbe only
cat "$DIR"/ministers-t.cooked.mp3.tmplist | sed \
    -e '/PM.*scene8[-_]/!d' \
    -e '/^\(\(high\|middle\) split\|bass\)	/d' \
    -e '/^\(\|D\|D\^[^3]\)PM	.*bar799/d' \
    -e '/^\(\|D\|D\^[^4]\)PM	.*bar807/d' \
    -e '/^\(\|D\|D\^[^4]\)PM	.*bar839/d' \
    -e 's/^\([^	]*\)	//' \
    > Abbe.mp3.urllist
cat "$DIR"/elders-a.mp3.tmplist | sed \
    -e '/^doves.*scene9[-_]/!d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    >> Abbe.mp3.urllist
cat "$DIR"/ministers-t.cooked.mp3.tmplist | sed \
    -e '/PM.*scene15[-_]/!d' \
    -e '/^\(high\|middle\) split	/d' \
    -e '/^\(\|D\|D\^[^4]\)PM	.*bar1785/d' \
    -e '/^\(\|D\|D\^[^5]\)PM	.*bar1818/d' \
    -e '/^\(\|D\|D\^[^6]\)PM	.*bar1830/d' \
    -e 's/^\([^	]*\)	//' \
    >> Abbe.mp3.urllist

# MP3s: bert only
cat "$DIR"/ministers-t.cooked.mp3.tmplist | sed \
    -e '/PM.*scene8[-_]/!d' \
    -e '/^\(\(middle\|low\) split\|bass\)	/d' \
    -e '/^\(\|D\|D\^[^5]\)PM	.*bar799/d' \
    -e '/^\(p\|D\|D\^[^p]\)PM	.*bar807/d' \
    -e '/^\(\|D\|D\^[^3]\)PM	.*bar839/d' \
    -e 's/^\([^	]*\)	//' \
    > bert.mp3.urllist
cat "$DIR"/elders-t.mp3.tmplist | sed \
    -e '/^doves.*scene9[-_]/!d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    >> bert.mp3.urllist
cat "$DIR"/ministers-t.cooked.mp3.tmplist | sed \
    -e '/PM.*scene15[-_]/!d' \
    -e '/^\(middle\|low\) split	/d' \
    -e '/^\(p\|D\|D\^[^p]\)PM	.*bar1785/d' \
    -e '/^\(\|D\|D\^[^3]\)PM	.*bar1818/d' \
    -e '/^\(\|D\|D\^[^6]\)PM	.*bar1830/d' \
    -e 's/^\([^	]*\)	//' \
    >> bert.mp3.urllist

### Peacocks/Courtiers soprano low
#     Laura Pitone and Avery Cole
sed -e '/^soprano p\(61\|71\|82\|105\|120\) hi	/d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/peacocks-s.mp3.tmplist > X-peacocks-soprano-low.mp3.urllist

### Peacocks/Courtiers alto
#     Eliza Weinberger (Joanne Nicklas's daughter)
sed -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/peacocks-a.mp3.tmplist > X-peacocks-alto.mp3.urllist

### Myna Birds/Courtiers soprano low
#     Gast/Verrilli
sed -e '/^soprano p\(61\|71\|82\|105\|120\) hi	/d' \
    -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/mynas-s.mp3.tmplist > X-mynas-soprano-low.mp3.urllist

### Myna Birds/Courtiers alto
#     Gast/Verrilli
sed -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/mynas-a.mp3.tmplist > X-mynas-alto.mp3.urllist

### Jackals/Weavers tenor
#     Heather Barney & David Gordon Mitten
sed -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/jackals-t.mp3.tmplist > X-jackals-tenor.mp3.urllist

### Doves/Village Elders alto
#     Joanne Nicklas
sed -e 's/^\([^	]*\)	\(.*\)$/\2	out_file_suffix:---\1/' \
    "$DIR"/elders-a.mp3.tmplist > X-elders-alto.mp3.urllist

#####  video
if [ "$INDEX_VIDEO" = "$INDEX" ]; then
    tmplist=big.mp3.tmplist
else
    tmplist=big.video.tmplist
fi
if [ ! -e "$tmplist" ]; then
    echo "... big list" >&2
    ./plinks.pl -hb -t "$INDEX_VIDEO" > "$tmplist"
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
	./plinks.pl -hb -t "$INDEX" > "$tmplist"
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
	./plinks.pl -hb -t "$INDEX" > "$tmplist"
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
    ./plinks.pl -hb -t "$INDEX_PDF" > "$tmplist"
fi
echo "... score" >&2
./plinks.pl "$INDEX_PDF" \
    | sed  -e '/\.pdf$/I!d;/^[^	]*score/I!d;/LibrettoBook/d' \
           -e 's/^[^	]*	//' \
           -e 's/^[^	]*	//' > score.pdf.urllist
