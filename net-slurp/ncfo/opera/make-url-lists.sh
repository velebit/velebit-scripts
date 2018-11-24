#!/bin/bash

DO_WIPE=
INDEX_REBELS=
INDEX_EMPIRE=
INDEX_SOLO=
INDEX_DEMO=
INDEX_ORCH=
INDEX_PDF=
INDEX_VIDEO=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --wipe)     DO_WIPE=yes; shift ;;
        #--mp3)      INDEX_MP3="$2"; shift; shift ;;
        --rebels)   INDEX_REBELS="$2"; shift; shift ;;
        --empire)   INDEX_EMPIRE="$2"; shift; shift ;;
        --solo)     INDEX_SOLO="$2"; shift; shift ;;
        --demo)     INDEX_DEMO="$2"; shift; shift ;;
        --orch)     INDEX_ORCH="$2"; shift; shift ;;
        --pdf)      INDEX_PDF="$2"; shift; shift ;;
        --video)    INDEX_VIDEO="$2"; shift; shift ;;
        *)
            echo "Unknown argument: '$1'" >&2; exit 1 ;;
    esac
done

DIR=tmplists
rm -f *.tmplist "$DIR"/*.tmplist
if [ -n "$DO_WIPE" ]; then rm -f *.urllist "$DIR"/*.urllist; fi
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

base_uri=http://www.familyopera.org/drupal/DUMMY/

##### generic prep

# NOTE: this is an extraction implementation based on plinks, for use
# with MP3s organized into text sections.  If the MP3s are organized
# into a table, a different kind of solution based on
# extract-column-links will be needed; see e.g. Weaver's Wedding 2016.

blist () {
    local index="$1"; shift
    local biglist="${index##*/}"; biglist="$DIR/${biglist%%.html}.tmplist"
    if [ ! -e "$biglist" ]; then
        echo "... $biglist" >&2
        ./plinks.pl -hb -li -plt -lt -lb -t -la \
		    --base "$base_uri" "$index" > "$biglist"
    fi
    echo "$biglist"
}

extract_section () {
    local biglist="$1"; shift
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

    cat "$biglist" \
        | sed -e '/\.mp3$/I!d;/^'"$section"'/I!d' \
              -e 's/^[^	]*	//' \
              -e 's/^ACT ONE/Act I/' \
              -e 's/^ACT TWO/Act II/' \
              -e 's/^ACT /Act /' \
              -e 's/^Act \([^ 	]*\),/Act \1/' \
              -e 's,^\([^	]*\)SCENE ONE,\1Scene 1,' \
              -e 's,^\([^	]*\)SCENE TWO,\1Scene 2,' \
              -e 's,^\([^	]*\)SCENE THREE,\1Scene 3,' \
              -e 's,^\([^	]*\)SCENE FOUR,\1Scene 4,' \
              -e 's,^\([^	]*\)SCENE FIVE,\1Scene 5,' \
              -e 's,^\([^	]*\)SCENE ,\1Scene ,' \
              -e 's,^\([^	]*Scene [^ :	]*\)[^	]*	,\1	,' \
              -e 's,^\([^	]*	\)[^	]*	,\1,' \
              -e 's,^\([^	]*	\)[^	]*	,\1,' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)(  */\1(/' \
              -e 's/^\([^	]*\)  *)/\1)/' \
              -e 's/   */ /g' -e 's/^  *//' -e 's/  *	/	/g' \
              -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
              -e 's,\xe2\x80\x99,'\'',g' \
        > "$DIR"/"$file".mp3.tmplist
}

extract_demorch () {
    local biglist="$1"; shift
    local section="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

#              -e 's,^\([^	]*	\)[^	]*	,\1	,' \
    local out_tag=out_file
    cat "$biglist" \
        | sed -e '/\.mp3$/I!d' \
              -e 's/^ACT ONE/Act I/' \
              -e 's/^ACT TWO/Act II/' \
              -e 's/^ACT /Act /' \
              -e 's/^Act \([^ 	]*\),/Act \1/' \
              -e 's,^\([^	]*\)SCENE ONE,\1Scene 1,' \
              -e 's,^\([^	]*\)SCENE TWO,\1Scene 2,' \
              -e 's,^\([^	]*\)SCENE THREE,\1Scene 3,' \
              -e 's,^\([^	]*\)SCENE FOUR,\1Scene 4,' \
              -e 's,^\([^	]*\)SCENE FIVE,\1Scene 5,' \
              -e 's,^\([^	]*\)SCENE ,\1Scene ,' \
              -e 's,^\([^	]*Scene [^ :	]*\)[^	]*	,\1	,' \
              -e 's/^\([^	]*	\)[^	]*	/\1/' \
              -e 's/^\([^	]*	\)[^	]*\(	[0-9]*\.\)/\1\2/' \
              -e 's,^\([^	]*	\)[0-9]*\.  *,\1,' \
              -e 's,^\([^	]*	[^	]*\)([^()	]*),\1,' \
              -e 's,^\([^	]*	[^	]*\)([^()	]*),\1,' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e 's/^\([^	]*	\)[^	]*	/\1/' \
              -e 's,^\([^	]*	\)[0-9]*\.  *,\1,' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e '/^[^	]*	'"$section"'/I!d' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e 's/^\([^	]*\)	/\1 /' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)(  */\1(/' \
              -e 's/^\([^	]*\)  *)/\1)/' \
              -e 's/   */ /g' -e 's/^  *//' -e 's/  *	/	/g' \
              -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
              -e 's,\xe2\x80\x99,'\'',g' \
              > "$DIR"/"$file".mp3.tmplist
}

extract_satb_sections () {
    local biglist="$1"; shift
    local sec_prefix="$1"; shift
    local sec_suffix="$1"; shift
    local base="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    for voice in 'SOPRANO' 'ALTO' 'ALTO C' 'TENOR' 'BASS'; do
        short="`echo "$voice" | sed -e 's/^\(.\)[^ ]* \?/\1/;y/SATBC/satbc/'`"
        full_voice="$voice"
        extract_section "$biglist" \
            "$sec_prefix$full_voice$sec_suffix" "$base-$short" \
            "$files_prefix`echo "$short" | sed -e 'y/satb/SATB/'` " \
            "$files_suffix"
    done
}

#extract_satb_sections "$biglist" '' ' MP3s' 'courtiers' 'Cou' ''
#extract_section "$biglist" 'AZARMIK' 'Azarmik-cit3'

if [ -n "$INDEX_REBELS" ]; then
    extract_satb_sections "$(blist "$INDEX_REBELS")" '' ' MP3s' 'rebels'
fi
if [ -n "$INDEX_EMPIRE" ]; then
    extract_satb_sections "$(blist "$INDEX_EMPIRE")" '' ' MP3s' 'empire'
fi
if [ -n "$INDEX_SOLO" ]; then
    extract_section "$(blist "$INDEX_SOLO")" 'HAN SOLO' 'han'
fi
if [ -n "$INDEX_DEMO" ]; then
    extract_demorch "$(blist "$INDEX_DEMO")" 'Demo' 'demo'
fi
if [ -n "$INDEX_ORCH" ]; then
    extract_demorch "$(blist "$INDEX_ORCH")" \
                    'Overture\|Orchestra.*' 'orchestra'
fi


cat "$DIR"/*-{s,a,ac,t,b}.mp3.tmplist | sed \
    -e '/KCCC/d' \
    > X-all-voices.mp3.urllist

cp "$DIR"/han.mp3.tmplist test-han.mp3.urllist
cp "$DIR"/rebels-t.mp3.tmplist rebels-t.mp3.urllist
cp "$DIR"/empire-t.mp3.tmplist empire-t.mp3.urllist

if false; then   ##### TODO ##### no voice part assignments are available yet

### Katarina (soprano 1 with some alto)
# MP3s
cat "$DIR"/all-s.mp3.tmplist | sed \
    -e '/Act I Scene 1e/,$d' \
    -e '/soprano 2/Id;/\(low\|middle\) split/Id' \
    -e '/KCCC/d;/Townie/d' \
    > Katarina.mp3.urllist
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act I Scene 1e/!d' \
    -e '/KCCC/d;/Townie/d' \
    >> Katarina.mp3.urllist
cat "$DIR"/all-s.mp3.tmplist | sed \
    -e '1,/Act I Scene 1e/d;/Act I Scene 1e/d' \
    -e '/Act I Scene 5/,$d' \
    -e '/soprano 2/Id;/\(low\|middle\) split/Id' \
    -e '/KCCC/d;/Townie/d' \
    >> Katarina.mp3.urllist
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act I Scene 5/!d' \
    -e '/KCCC/d;/Townie/d' \
    >> Katarina.mp3.urllist
cat "$DIR"/all-s.mp3.tmplist | sed \
    -e '1,/Act I Scene 5/d;/Act I Scene 5/d' \
    -e '/Act II Scene 5/,$d' \
    -e '/soprano 2/Id;/\(low\|middle\) split/Id' \
    -e '/KCCC/d;/Townie/d' \
    >> Katarina.mp3.urllist
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act II Scene 5/!d' \
    -e '/KCCC/d;/Townie/d' \
    >> Katarina.mp3.urllist

### Abbe and Luka (alto with some tenor)
# MP3s
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act I Scene 1e/,$d' \
    -e '/KCCC/d;/Townie/d' \
    > Abbe+Luka.mp3.urllist
cat "$DIR"/all-t.mp3.tmplist "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act I Scene 1e/!d' \
    -e '/A Act I Scene 1e.*Bars 47-62/Id' \
    -e '/tenor 2/Id' \
    -e '/KCCC/d;/Townie/d' \
    >> Abbe+Luka.mp3.urllist
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '1,/Act I Scene 1e/d;/Act I Scene 1e/d' \
    -e '/Act I Scene 5/,$d' \
    -e '/KCCC/d;/Townie/d' \
    >> Abbe+Luka.mp3.urllist
cat "$DIR"/all-t.mp3.tmplist "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act I Scene 5/!d' \
    -e '/tenor 2/Id' \
    -e '/KCCC/d;/Townie/d;/countermelody/d' \
    >> Abbe+Luka.mp3.urllist
cat "$DIR"/all-a.mp3.tmplist | sed \
    -e '1,/Act I Scene 5/d;/Act I Scene 5/d' \
    -e '/Act II Scene 4/,$d' \
    -e '/if I had a dime.*alto 2/Id' \
    -e '/KCCC/d;/Townie/d' \
    >> Abbe+Luka.mp3.urllist
cat "$DIR"/all-t.mp3.tmplist "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act II Scene 4/!d' \
    -e '/middle split/d' \
    -e '/KCCC/d;/Townie/d' \
    >> Abbe+Luka.mp3.urllist
cat "$DIR"/all-t.mp3.tmplist "$DIR"/all-a.mp3.tmplist | sed \
    -e '/Act II Scene 5/!d' \
    -e '/tenor 2/Id' \
    -e '/KCCC/d;/Townie/d' \
    >> Abbe+Luka.mp3.urllist

### bert (tenor)
# MP3s
cat "$DIR"/all-t.mp3.tmplist | sed \
    -e '/tenor 2/Id' \
    -e '/KCCC/d;/Townie/d' \
    > bert.mp3.urllist

fi   ##### TODO #####

if false; then   ##### TODO ##### no videos are available yet

#####  video
echo "... video" >&2
biglist="$(blist "$INDEX_VIDEO")"
cat "$biglist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/I!d;/SLOW/Id' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > mirror-fullsp.video.urllist
cat "$biglist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/Id;/SLOW/Id' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > regular-fullsp.video.urllist
cat "$biglist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/I!d;/SLOW/I!d' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > mirror-slow.video.urllist
cat "$biglist" \
    | sed -e '/\.mp4$/I!d' \
          -e '/MIRROR/Id;/SLOW/I!d' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > regular-slow.video.urllist
cat "$biglist" \
    | sed -e '/\.pdf$/I!d' \
          -e '/sponsorship/Id' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
          -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
    > blocking.video.urllist

fi   ##### TODO #####

### demo MP3s
if [ -e .generate-demo -a -e tmplists/demo.mp3.tmplist ]; then
    echo "... demo" >&2
    cat tmplists/demo.mp3.tmplist \
        > demo.mp3.urllist
fi

### orchestra-only MP3s
if [ -e .generate-orchestra -a -e tmplists/orchestra.mp3.tmplist ]; then
    echo "... orchestra" >&2
    cat tmplists/orchestra.mp3.tmplist \
        > orchestra.mp3.urllist
fi

### score PDFs

if [ -n "$INDEX_PDF" ]; then
    echo "... score" >&2

    ./plinks.pl --base "$base_uri" "$INDEX_PDF" \
        | sed  -e '/\.pdf$/I!d' \
               -e '/^[^	]*score/I!d;/LibrettoBook/d;/OPERA-PARTY/d' \
               -e 's/^[^	]*	//' \
               -e 's/^[^	]*	//' > score.pdf.urllist
fi
