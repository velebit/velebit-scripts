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
              -e 's/^Act \([^ 	]*\) Scene \([^ 	]*\)/\1.\2/' \
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
              -e 's/^Act \([^ 	]*\) Scene \([^ 	]*\)/\1.\2/' \
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
    local list_prefix="$1"; shift
    local list_suffix="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    for voice in 'SOPRANO' 'ALTO' 'ALTO C' 'TENOR' 'BASS'; do
        short="`echo "$voice" | sed -e 's/^\(.\)[^ ]* \?/\1/;y/SATBC/satbc/'`"
        full_voice="$voice"
        extract_section "$biglist" \
            "$sec_prefix$full_voice$sec_suffix" \
            "$list_prefix$short$list_suffix" \
            "$files_prefix`echo "$short" | sed -e 'y/satb/SATB/'` " \
            "$files_suffix"
    done
}

#extract_satb_sections "$biglist" '' ' MP3s' 'courtiers-' '' 'Cou' ''
#extract_section "$biglist" 'AZARMIK' 'Azarmik-cit3'

if [ -n "$INDEX_REBELS" ]; then
    extract_satb_sections "$(blist "$INDEX_REBELS")" '' ' MP3s' '' '-rebels'
fi
if [ -n "$INDEX_EMPIRE" ]; then
    extract_satb_sections "$(blist "$INDEX_EMPIRE")" '' ' MP3s' '' '-empire'
fi
if [ -n "$INDEX_SOLO" ]; then
    # Hack: Luke gets identified as "PRINCIPAL SOLOISTS" instead, not fixing.
    extract_section "$(blist "$INDEX_SOLO")" "PRINCIPAL SOLOISTS" "luke"
    extract_section "$(blist "$INDEX_SOLO")" "HAN SOLO" "han"
    extract_section "$(blist "$INDEX_SOLO")" "PRINCESS LEIA" "leia"
    extract_section "$(blist "$INDEX_SOLO")" "OBI-WAN KENOBI" "obiwan"
    extract_section "$(blist "$INDEX_SOLO")" "DARTH VADER" "darth"
    extract_section "$(blist "$INDEX_SOLO")" "C-3PO" "c3po"
    extract_section "$(blist "$INDEX_SOLO")" "R2-D2" "r2d2"
    extract_section "$(blist "$INDEX_SOLO")" "CHEWBACCA" "chewie"
    extract_section "$(blist "$INDEX_SOLO")" "JABBA THE HUTT" "jabba"
    extract_section "$(blist "$INDEX_SOLO")" "UNCLE OWEN" "owen"
fi
if [ -n "$INDEX_DEMO" ]; then
    extract_demorch "$(blist "$INDEX_DEMO")" 'Demo' 'demo'
fi
if [ -n "$INDEX_ORCH" ]; then
    extract_demorch "$(blist "$INDEX_ORCH")" \
                    'Overture\|Orchestra.*' 'orchestra'
fi


if [ -n "$INDEX_REBELS" -a -n "$INDEX_EMPIRE" ]; then
    cat "$DIR"/{s,a,ac,t,b}-*.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > X-all-voices.mp3.urllist
fi

set --
if [ -n "$INDEX_REBELS" ]; then set -- "$@" rebels; fi
if [ -n "$INDEX_EMPIRE" ]; then set -- "$@" empire; fi
for ch in "$@"; do
    for vp in s a t b; do
        cp "$DIR"/"$vp"-"$ch".mp3.tmplist X-"$vp"-"$ch".mp3.urllist
    done
done

### Katarina (Luke!!!)
# MP3s
if [ -n "$INDEX_SOLO" ]; then
    cat "$DIR"/luke.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > Katarina.mp3.urllist
fi
if [ -n "$INDEX_REBELS" ]; then
    cp "$DIR"/s-rebels.mp3.tmplist s-rebels.mp3.urllist
fi

### bert (Chewie!!!)
# MP3s
if [ -n "$INDEX_SOLO" ]; then
    cat "$DIR"/chewie.mp3.tmplist | sed \
        -e 's/:\(At the spaceport\)/:I.4 \1/I' \
        > bert.mp3.urllist
fi
if [ -n "$INDEX_REBELS" ]; then
    cp "$DIR"/t-rebels.mp3.tmplist t-rebels.mp3.urllist
fi

### Abbe and Luka (???)
# MP3s
if [ -n "$INDEX_REBELS" ]; then
    cat "$DIR"/a-rebels.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > Abbe+Luka.mp3.urllist
fi

### burning CDs
if [ -e .generate-cd -a -n "$INDEX_REBELS" ]; then
    : #cp "$DIR"/s-rebels.mp3.tmplist s-rebels.mp3.urllist
    : #cp "$DIR"/a-rebels.mp3.tmplist a-rebels.mp3.urllist
    : #cp "$DIR"/t-rebels.mp3.tmplist t-rebels.mp3.urllist
    : #cp "$DIR"/b-rebels.mp3.tmplist b-rebels.mp3.urllist
fi
if [ -e .generate-cd -a -n "$INDEX_EMPIRE" ]; then
    cp "$DIR"/s-empire.mp3.tmplist s-empire.mp3.urllist
    cp "$DIR"/a-empire.mp3.tmplist a-empire.mp3.urllist
    cp "$DIR"/t-empire.mp3.tmplist t-empire.mp3.urllist
    : #cp "$DIR"/b-empire.mp3.tmplist b-empire.mp3.urllist
fi

#####  video
if [ -n "$INDEX_VIDEO" ]; then
    biglist="$(blist "$INDEX_VIDEO")"
    cat "$biglist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/I!d;/SLOW/Id' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > mirror-fullsp.video.urllist
    cat "$biglist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/Id;/SLOW/Id' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > regular-fullsp.video.urllist
    cat "$biglist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/I!d;/SLOW/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > mirror-slow.video.urllist
    cat "$biglist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/Id;/SLOW/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > regular-slow.video.urllist
    cat "$biglist" \
        | sed -e '/\.pdf$/I!d' \
              -e '/sponsorship/Id' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > blocking.video.urllist
fi

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
