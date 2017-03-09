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
    ./plinks.pl -hb -t "$INDEX" > "$tmplist"
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
	      -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
	      -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
	      -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
	      -e 's/^\([^	]*\)[’]/\1'\''/' \
	      -e 's/^\([^	]*\)[’]/\1'\''/' \
	      -e 's/^\([^	]*\)[’]/\1'\''/' \
	      -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
	      -e 's,^.*/sites/,http://www.familyopera.org/drupal/sites/,' \
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

extract_satb_sections 'CITIZEN ' ' MP3s' 'citizens' 'Cit' ''
extract_satb_sections 'COURTIER ' ' MP3s' 'courtiers' 'Cou' ''

#extract_section 'FAROUK' 'Farouk-cit1'
#extract_section 'SORAYA' 'Soraya-cit2'
#extract_section 'ROSHAN AND BAHAAR' 'Roshan+Bahaar-cit'
extract_section 'AZARMIK' 'Azarmik-cit3'
extract_section 'FARZAD' 'Farzad-cit4'
extract_section 'SHERBAN' 'Sherban-cit5'
extract_section 'RAMIN' 'Ramin-cit6'
extract_section 'KAVEH' 'Kaveh-cit7'
extract_section 'AMIR' 'Amir-cit8'
extract_section 'DARA' 'Dara-cit9'
extract_section 'MEHRDAD' 'Mehrdad-hf1'
extract_section 'HADI' 'Hadi-hf2'
extract_section 'KARIM' 'Karim-hf3'
#extract_section 'FAZLOLLA' 'Fazlolla-hf4'
#extract_section 'ZETHAR' 'Zethar-cou'
#extract_section 'BIZZETHA' 'Bizzetha-cou'
#extract_section 'BIGTHA' 'Bigtha-cou'
#extract_section 'ABAGTHA' 'Abagtha-cou'
#extract_section 'HATHACH' 'Hathach-cou'
#extract_section 'SAMIREH' 'Samireh-cou'
extract_section 'CARSHENA' 'Carshena-cou'
#extract_section 'SHETHAR AND ADMATHA' 'Shethar+Admatha-cou'
#extract_section 'SUHRAB AND ZENDA' 'Suhrab+Zenda-cou'
#extract_section 'GOLPAR' 'Golpar-cou'

###### individual parts
#echo "... individual parts" >&2
#
#for i in s a t b; do
#    cat "$DIR"/ministers-"$i".mp3.tmplist | sed \
#	-e 's/$/	out_file_suffix:---/' \
#	-e 's/^\(\([^	]* \)\?\(bar \?[1-9][^	]*\)	\([^	]*\)	\([^	]*\)	.*	out_file_suffix:---\)$/\1\2\5 \3/' \
#	-e 's/^\([^	]*\)	//' \
#	-e 's/^\*\?\(page \([1-9][0-9]*\).*	out_file_suffix:---\)$/\1PMs p\2/' \
#	-e 's/^\([^	]*\)	//' \
#	-e 's/^\(\([^	]*\)	.*	out_file_suffix:---\)$/\1\2/' \
#	-e 's/	out_file_suffix:---$//' \
#	> "$DIR"/ministers-"$i".cooked.mp3.tmplist
#done

extract_section 'DEMO MP3s' 'demo'

### Katarina (citizens soprano, Harbona)
# MP3s
cat "$DIR"/citizens-s.mp3.tmplist | sed \
    -e 's/NEVER_MATCHES//' \
    > Katarina.mp3.urllist
cat "$DIR"/demo.mp3.tmplist | sed \
    -e '/TheSentence/!d' \
    >> Katarina.mp3.urllist

### Abbe (citizens alto)
# MP3s
cat "$DIR"/citizens-a.mp3.tmplist | sed \
    -e 's/NEVER_MATCHES//' \
    > Abbe.mp3.urllist
#cat "$DIR"/demo.mp3.tmplist | sed \
#    -e '/TheSentence/!d' \
#    >> Abbe.mp3.urllist

### bert (citizens tenor, Azarmik)
# MP3s
cat "$DIR"/citizens-t.mp3.tmplist | sed \
    -e 's/NEVER_MATCHES//' \
    > bert.mp3.urllist
cat "$DIR"/Azarmik-cit3.mp3.tmplist \
    >> bert.mp3.urllist

#### Meredith Gast (citizens/Haman's friends soprano + Mehrdad)
cat "$DIR"/citizens-s.mp3.tmplist \
    > X-MeredithGast.mp3.urllist
cat "$DIR"/Mehrdad-hf1.mp3.tmplist \
    >> X-MeredithGast.mp3.urllist

#### Erin Gast (citizens/Haman's friends alto C + Hadi)
#### Sara Verrilli (citizens/Haman's friends alto C + Karim)
cat "$DIR"/citizens-ac.mp3.tmplist \
    > X-ErinGast+SaraVerrilli.mp3.urllist
cat "$DIR"/Hadi-hf2.mp3.tmplist \
    >> X-ErinGast+SaraVerrilli.mp3.urllist
cat "$DIR"/Karim-hf3.mp3.tmplist \
    >> X-ErinGast+SaraVerrilli.mp3.urllist

#### Razi Youmans (citizens/Haman's friends soprano + Hadi)
cat "$DIR"/citizens-s.mp3.tmplist \
    > X-RaziYoumans.mp3.urllist
cat "$DIR"/Hadi-hf2.mp3.tmplist \
    >> X-RaziYoumans.mp3.urllist

#### Mindy Koyanis (citizens/Haman's friends tenor)
#### Hope Kelley (citizens/Haman's friends tenor)
cat "$DIR"/citizens-t.mp3.tmplist \
    > X-Xcitizens-t.mp3.urllist

#### Heather Barney (courtiers/chamberlains tenor + Carshena)
cat "$DIR"/courtiers-t.mp3.tmplist | sed \
    -e '/LikeIraqVerse2/d;/FeastForUs1/d;/InsideLookinOut/d' \
    > X-XHeatherBarney.mp3.urllist
cat "$DIR"/Carshena-cou.mp3.tmplist \
    >> X-XHeatherBarney.mp3.urllist

#### Joanne Nicklas (courtiers/chamberlains alto + Edict TBD)
cat "$DIR"/courtiers-a.mp3.tmplist | sed \
    -e '/LikeIraqVerse2/d;/FeastForUs1/d;/InsideLookinOut/d' \
    > X-XJoanneNicklas.mp3.urllist
cat "$DIR"/Farzad-cit4.mp3.tmplist \
    "$DIR"/Sherban-cit5.mp3.tmplist \
    "$DIR"/Ramin-cit6.mp3.tmplist \
    "$DIR"/Kaveh-cit7.mp3.tmplist \
    "$DIR"/Amir-cit8.mp3.tmplist \
    "$DIR"/Dara-cit9.mp3.tmplist \
    >> X-XJoanneNicklas.mp3.urllist

#### Eliza Weinberger (courtiers/chamberlains soprano + Edict TBD)
cat "$DIR"/courtiers-s.mp3.tmplist | sed \
    -e '/LikeIraqVerse2/d;/FeastForUs1/d;/InsideLookinOut/d' \
    > X-XElizaWeinberger.mp3.urllist
cat "$DIR"/Farzad-cit4.mp3.tmplist \
    "$DIR"/Sherban-cit5.mp3.tmplist \
    "$DIR"/Ramin-cit6.mp3.tmplist \
    "$DIR"/Kaveh-cit7.mp3.tmplist \
    "$DIR"/Amir-cit8.mp3.tmplist \
    "$DIR"/Dara-cit9.mp3.tmplist \
    >> X-XElizaWeinberger.mp3.urllist

#####  video
if [ "$INDEX_VIDEO" = "$INDEX" ]; then
    tmplist=big.mp3.tmplist
else
    tmplist=big.video.tmplist
fi
if [ ! -e "$tmplist" ]; then
    echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
    ./plinks.pl -hb -t "$INDEX_VIDEO" > "$tmplist"
fi
echo "... video" >&2
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/I!d;/SLOW/Id' \
          -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' \
    > mirror-fullsp.video.urllist
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/Id;/SLOW/Id' \
          -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' \
    > regular-fullsp.video.urllist
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/I!d;/SLOW/I!d' \
          -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' \
    > mirror-slow.video.urllist
cat "$tmplist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/Id;/SLOW/I!d' \
          -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' \
    > regular-slow.video.urllist
cat "$tmplist" \
    | sed -e '/\.pdf$/I!d' \
          -e '/sponsorship/Id' \
          -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' \
    > blocking.video.urllist

### demo MP3s
if [ -e .generate-demo ]; then
    tmplist=big.mp3.tmplist
    if [ ! -e "$tmplist" ]; then
	echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
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
	echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
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
    echo "... big list (`echo "$tmplist" | sed -e 's/^big\.//;s/\..*//'`)" >&2
    ./plinks.pl -hb -t "$INDEX_PDF" > "$tmplist"
fi
echo "... score" >&2
./plinks.pl "$INDEX_PDF" \
    | sed  -e '/\.pdf$/I!d;/^[^	]*score/I!d;/LibrettoBook/d' \
           -e 's/^[^	]*	//' \
           -e 's/^[^	]*	//' > score.pdf.urllist
