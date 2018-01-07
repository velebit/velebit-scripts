#!/bin/sh
INDEX="$1"; shift
INDEX_PDF="$1"; shift
INDEX_VIDEO="$1"; shift
[ -z "$INDEX" ] && INDEX="mp3/index.html"
[ -z "$INDEX_PDF" ] && INDEX_PDF="${INDEX}"
[ -z "$INDEX_VIDEO" ] && INDEX_VIDEO="video/index.html"

DIR=tmplists
rm -f *.urllist "$DIR"/*.urllist *.tmplist "$DIR"/*.tmplist
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

##### generic prep

# NOTE: this is an extraction implementation based on plinks, for use
# with MP3s organized into text sections.  If the MP3s are organized
# into a table, a different kind of solution based on
# extract-column-links will be needed; see e.g. Weaver's Wedding 2016.

tmplist=big.mp3.tmplist
if [ ! -e "$tmplist" ]; then
    echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
    ./plinks.pl -hb -li -lt -t "$INDEX" > "$tmplist"
fi

extract_section () {
    local section="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local text_style=replace
    #local text_style=prepend
    local out_tag=out_file
    if [ "$text_style" = prepend ]; then
	out_tag=out_file_prefix
	files_suffix="$files_suffix "
    fi

    cat "$tmplist" \
	| sed -e '/\.mp3$/I!d;/^'"$section"'/I!d' \
	      -e 's/^[^	]*	//' \
	      -e 's,^\([^	]*\) // ,\1 ,' \
	      -e 's,^\([^	]*\) // ,\1 ,' \
	      -e 's,^\([^	]*\) // ,\1 ,' \
	      -e 's/^\([^	]*\)	/\1 /' \
	      -e 's/^\([^()	]*	\)[^	]*	/\1	/' \
	      -e 's/^\([^()	]*\) *([^()	]*)/\1/' \
	      -e 's/^\([^	]*\)	/\1 /' \
	      -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
	      -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
	      -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
	      -e 's/^\([^	]*\)[’]/\1'\''/' \
	      -e 's/^\([^	]*\)[’]/\1'\''/' \
	      -e 's/^\([^	]*\)[’]/\1'\''/' \
	      -e 's/   */ /g' -e 's/^  *//' -e 's/  *	/	/g' \
	      -e 's/\(Scene 1\) 1/\1/' -e 's/\(Scene 2\) 2/\1/' \
	      -e 's/\(Scene [1-9][a-z]\?\) /\1 - /' -e 's/ - - / - /' \
	      -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
	      -e 's,^.*/sites/,http://www.familyopera.org/drupal/sites/,' \
	      -e 's,\xe2\x80\x99,'\'',g' \
	> "$DIR"/"$file".mp3.tmplist
}

extract_satb_sections () {
    local sec_prefix="$1"; shift
    local sec_suffix="$1"; shift
    local base="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    for voice in 'SOPRANO' 'ALTO' 'ALTO C' 'TENOR' 'BASS'; do
	short="`echo "$voice" | sed -e 's/^\(.\)[^ ]* \?/\1/;y/SATBC/satbc/'`"
	full_voice="$voice"
	extract_section "$sec_prefix$full_voice$sec_suffix" "$base-$short" \
	    "$files_prefix`echo "$short" | sed -e 'y/satb/SATB/'` " \
	    "$files_suffix"
    done
}

#extract_satb_sections '' ' MP3s' 'courtiers' 'Cou' ''
#extract_section 'AZARMIK' 'Azarmik-cit3'

extract_satb_sections '' '	' 'all'

cat "$DIR"/all-{s,a,ac,t,b}.mp3.tmplist \
    > X-all-voices.mp3.urllist

extract_section 'DEMO MP3s' 'demo'

### Katarina (soprano 1)
# MP3s
cat "$DIR"/all-s.mp3.tmplist | sed \
    -e '/soprano 2/Id' \
    -e '/low split/Id' \
    > Katarina.mp3.urllist

### Abbe and Luka (alto)
# MP3s
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '/placeholder/d' \
    > Abbe+Luka.mp3.urllist

### bert (tenor)
# MP3s
cat "$DIR"/all-t.mp3.tmplist | sed \
    -e '/placeholder/d' \
    > bert.mp3.urllist
#cat "$DIR"/all-b.mp3.tmplist | sed \
#    -e '/low split/Id' \
#    -e '/low bass/Id' \
#    >> bert.mp3.urllist

#####  video
if [ "$INDEX_VIDEO" = "$INDEX" ]; then
    tmplist=big.mp3.tmplist
else
    tmplist=big.video.tmplist
fi
if [ ! -e "$tmplist" ]; then
    echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
    ./plinks.pl -hb -li -lt -t "$INDEX_VIDEO" > "$tmplist"
fi
echo "... video" >&2
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/I!d;/SLOW/Id' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > mirror-fullsp.video.urllist
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/Id;/SLOW/Id' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > regular-fullsp.video.urllist
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/I!d;/SLOW/I!d' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > mirror-slow.video.urllist
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/Id;/SLOW/I!d' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > regular-slow.video.urllist
cat "$tmplist" \
    | sed -e '/\.pdf$/I!d' \
          -e '/sponsorship/Id' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > blocking.video.urllist

### demo MP3s
if [ -e .generate-demo ]; then
    echo "... demo" >&2
    cat tmplists/demo.mp3.tmplist \
	> demo.mp3.urllist
fi

### orchestra-only MP3s
if [ -e .generate-orchestra ]; then
    tmplist=big.mp3.tmplist
    if [ ! -e "$tmplist" ]; then
	echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
	./plinks.pl -hb -li -lt -t "$INDEX" > "$tmplist"
    fi
    echo "... orchestra" >&2
    cat "$tmplist" \
	| sed -e '/\.mp3$/I!d;/^[^	]*orchestra/I!d;/complete	/Id' \
	      -e 's/^[^	]*	//' \
	      -e 's/^[^	]*	//' \
	      -e 's/^[^	]*	//' \
	      -e 's/^\([^	]*\)	\(.*\)$/\2	out_file:\1/' \
	> orchestra.mp3.urllist
fi

### score PDFs
echo "... score" >&2
./plinks.pl "$INDEX_PDF" \
    | sed  -e '/\.pdf$/I!d;/^[^	]*score/I!d;/LibrettoBook/d;/OPERA-PARTY/d' \
           -e 's/^[^	]*	//' \
           -e 's/^[^	]*	//' > score.pdf.urllist
