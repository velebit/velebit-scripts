#!/bin/bash

DO_WIPE=
INDEX_CHORUS=
INDEX_SOLO=
INDEX_DEMO=
INDEX_ORCH=
INDEX_SCENE=
INDEX_PDF=
INDEX_VIDEO=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --wipe)     DO_WIPE=yes; shift ;;
        #--mp3)      INDEX_MP3="$2"; shift; shift ;;
        --chorus)   INDEX_CHORUS="$2"; shift; shift ;;
        --solo)     INDEX_SOLO="$2"; shift; shift ;;
        --demo)     INDEX_DEMO="$2"; shift; shift ;;
        --orch)     INDEX_ORCH="$2"; INDEX_SCENE="$2"; shift; shift ;;
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

# This combines an extraction implementation based on plinks, for use
# with MP3s organized into text sections, with a different kind of
# solution based on print-table-links for MP3s are organized into a
# table.  Look for "$plist" or "$tlist".

plist () {
    local index="$1"; shift
    local plist="${index##*/}"; plist="$DIR/${plist%%.html}.p.tmplist"
    if [ ! -e "$plist" ]; then
        echo "... $plist" >&2
        ./plinks.pl -hb -li -plt -lt -lb -t -la \
                    --base "$base_uri" "$index" > "$plist"
    fi
    echo "$plist"
}

tlist () {
    local index="$1"; shift
    local tlist="${index##*/}"; tlist="$DIR/${tlist%%.html}.t.tmplist"
    if [ ! -e "$tlist" ]; then
        echo "... $tlist" >&2
        ./print-table-links.pl -hb -nc -rb -eb -t -ea -ra -sep '~' -sl \
                               --base "$base_uri" "$index" > "$tlist"
    fi
    echo "$tlist"
}

extract_table_section () {
    local tlist="$1"; shift
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

    cat "$tlist" \
        | sed -e '/\.mp3$/I!d;/^'"$section"'/I!d' \
              -e 's/^[^	]*	//' \
              -e '/^[01]	/d' `# skip column 1 (and 0, for Piper)` \
              -e '/^3	/s,^\([^	]*	[^	]*	\),\1pan w ,' \
              -e 's/^[^	]*	//' \
              -e 's/^Act \([^ 	]*\) Scene \([^ 	]*\)/\1.\2/I' \
              -e 's/^Scene \([^ 	]*\)/sc\1/I' \
              -e 's/	/, /' \
              -e 's/	/ /' \
              -e 's/	/ /' \
              -e 's/^\([^	]*	\)[^	]*	/\1/' \
              -e 's/~/ /' \
              -e 's/~/, /' \
              -e 's/^\([^	]*\)[:\*\?"<>|~]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|~]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|~]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|~]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|~]/\1/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)(  */\1(/' \
              -e 's/^\([^	]*\)  *)/\1)/' \
              -e 's/   */ /g' -e 's/^  *//' -e 's/  *	/	/g' \
              -e 's/, *,/,/;s/, *,/,/' -e 's/  *,/,/g' \
              -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
              -e 's,\xe2\x80\x99,'\'',g' \
        > "$DIR"/"$file".mp3.tmplist
}

extract_demorch () {
    local plist="$1"; shift
    local section="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

#              -e 's,^\([^	]*	\)[^	]*	,\1	,' \
    local out_tag=out_file
    cat "$plist" \
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
              -e 's,^\([^	]*Scene [^	]*\)Scene ,\1S,I' \
              -e 's,^\([^	]*Scene [^ :	]*\)[^	]*	,\1	,' \
              -e 's/^Act \([^ 	]*\) Scene \([^ 	]*\)/\1.\2/' \
              -e 's/^Scene \([^ 	]*\)/sc\1/' \
              -e 's/^\([^	]*	\)[^	]*	/\1/' \
              -e 's/^\([^	]*	\)[^	]*	/\1/' \
              -e 's/^\([^	]*	\)[^	]*	/\1/' \
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
    local tlist="$1"; shift
    local sec_prefix="$1"; shift
    local sec_suffix="$1"; shift
    local list_prefix="$1"; shift
    local list_suffix="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    for voice in 'SOPRANO' 'ALTO' 'ALTO C' 'TENOR' 'BASS'; do
        short="`echo "$voice" | sed -e 's/^\(.\)[^ ]* \?/\1/;y/SATBC/satbc/'`"
        full_voice="$voice"
        extract_table_section "$tlist" \
            "$sec_prefix$full_voice$sec_suffix" \
            "$list_prefix$short$list_suffix" \
            "$files_prefix`echo "$short" | sed -e 'y/satb/SATB/'` " \
            "$files_suffix"
    done
}

if [ -n "$INDEX_CHORUS" ]; then
    extract_satb_sections "$(tlist "$INDEX_CHORUS")" '' ' MP3s' '' '-chorus'

    extract_table_section "$(tlist "$INDEX_CHORUS")" "SUPPORTING" \
                          "all-supporting"
    for s in clement thomasina walter myles edmund \
	     'cabin boy' \
	     'reveler 1' 'reveler 2' 'reveler 3' 'reveler 4' \
	     'captain gouda' 'henk' 'schenk' 'denk' \
	     jolye dowland \
	     soldier yeoman ; do
	f="${s// /-}"
	grep -i '\<'"$s"',' "$DIR"/all-supporting.mp3.tmplist \
	     > "$DIR"/"$f".mp3.tmplist
    done
fi
if [ -n "$INDEX_SOLO" ]; then
    extract_table_section "$(tlist "$INDEX_SOLO")" "Lady Mary" "lady-mary"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Sir Digory Piper" "piper"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Queen" "queen"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Sir Julius Caesar" "caesar"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Sir John K" "sir-john"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Parry" "parry"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Betty" "betty"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Ned" "ned"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Nan" "nan"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Cicely" "cicely"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Oswald" "oswald+susan"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Don Diego" \
                          "diego+felipe+leonora"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Paco, Pepe" \
                          "paco+pepe+pio+juancho"
    extract_table_section "$(tlist "$INDEX_SOLO")" "Margery, Dorcas" \
                          "margery+dorcas+amphillis+eunice+grissell"
fi
if [ -n "$INDEX_DEMO" ]; then
    extract_demorch "$(plist "$INDEX_DEMO")" 'Demo' 'demo'
fi
if [ -n "$INDEX_ORCH" ]; then
    extract_demorch "$(plist "$INDEX_ORCH")" \
                    'Overture\|Orchestra.*' 'orchestra'
fi
if [ -n "$INDEX_SCENE" ]; then
    extract_demorch "$(plist "$INDEX_SCENE")" \
                    'soundtrack\|sound track' 'scenes'
fi


if [ -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/{s,a,ac,t,b}-*.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > X-all-voices.mp3.urllist
fi

set --
if [ -n "$INDEX_CHORUS" ]; then set -- "$@" chorus; fi
for ch in "$@"; do
    for vp in s a t b; do
        cp "$DIR"/"$vp"-"$ch".mp3.tmplist X-"$vp"-"$ch".mp3.urllist
    done
done

### Katarina (Luke!!!)
# MP3s
#if [ -n "$INDEX_SOLO" ]; then
#    cat "$DIR"/luke.mp3.tmplist | sed \
#        -e '/NOOP/d' \
#        > Katarina.mp3.urllist
#fi
if [ -n "$INDEX_CHORUS" ]; then
    cp "$DIR"/s-chorus.mp3.tmplist s-chorus.mp3.urllist
fi

### bert (Chewie!!!)
# MP3s
#if [ -n "$INDEX_SOLO" -a -n "$INDEX_CHORUS" -a \
#     -n "$INDEX_DEMO" -a -n "$INDEX_ORCH" ]; then
#    cat "$DIR"/chewie.mp3.tmplist | sed \
#	-e '/Alderaan/,$d' \
#        > bert.mp3.urllist
#    cat "$DIR"/t-chorus.mp3.tmplist | sed \
#	-e '/I.m the Best.*Aliens/I,/Jabba/I!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/chewie.mp3.tmplist | sed \
#	-e '/Alderaan/,$!d' \
#	-e '/Alderaan.*orchestra/,$d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/orchestra.mp3.tmplist | sed \
#	-e '/Alderaan/!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/demo.mp3.tmplist | sed \
#	-e '/Alderaan/!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/chewie.mp3.tmplist | sed \
#	-e '1,/Alderaan.*orchestra/d' \
#	-e '1,/Prisoner.*Lament.*Chewbacca singing/I!d' \
#	-e '/Our Darkest Hour 2/I{;/Alderaan/!d;}' \
#        >> bert.mp3.urllist
#    cat "$DIR"/demo.mp3.tmplist | sed \
#	-e '/Prisoner.*Lament/I!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/chewie.mp3.tmplist | sed \
#	-e '1,/Prisoner.*Lament.*Chewbacca singing/Id' \
#	-e '1,/Prisoner Transfer.*without Chewbacca/I!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/demo.mp3.tmplist | sed \
#	-e '/Prisoner Transfer/I!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/t-chorus.mp3.tmplist | sed \
#	-e '/Grand Finale.*beginning/I!d' \
#        >> bert.mp3.urllist
#    cat "$DIR"/chewie.mp3.tmplist | sed \
#	-e '1,/Prisoner Transfer.*without Chewbacca/Id' \
#        >> bert.mp3.urllist
#    cat "$DIR"/t-chorus.mp3.tmplist | sed \
#	-e '/Grand Finale.*end/I,$!d' \
#        >> bert.mp3.urllist
#fi
if [ -n "$INDEX_CHORUS" ]; then
    cp "$DIR"/t-chorus.mp3.tmplist t-chorus.mp3.urllist
fi

### Abbe and Luka (???)
# MP3s
#if [ -n "$INDEX_CHORUS" ]; then
#    cat "$DIR"/a-chorus.mp3.tmplist | sed \
#        -e '/Droids/Id' \
#        -e '/a cappella/Id' \
#        -e '/Sandpeople/Id' \
#        -e '/Ghosts/Id' \
#        > Abbe+Luka.mp3.urllist
#fi
if [ -n "$INDEX_CHORUS" ]; then
    cp "$DIR"/a-chorus.mp3.tmplist a-chorus.mp3.urllist
fi

### burning CDs
if [ -e .generate-cd -a -n "$INDEX_CHORUS" ]; then
    : ##cp "$DIR"/s-chorus.mp3.tmplist s-chorus.mp3.urllist
    cp "$DIR"/a-chorus.mp3.tmplist a-chorus.mp3.urllist
    cp "$DIR"/t-chorus.mp3.tmplist t-chorus.mp3.urllist
    : ##cp "$DIR"/b-chorus.mp3.tmplist b-chorus.mp3.urllist
fi

#####  video
if [ -n "$INDEX_VIDEO" ]; then
    plist="$(plist "$INDEX_VIDEO")"
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/I!d;/SLOW/Id' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > mirror-fullsp.video.urllist
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/Id;/SLOW/Id' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > regular-fullsp.video.urllist
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/I!d;/SLOW/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > mirror-slow.video.urllist
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e '/MIRROR/Id;/SLOW/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              > regular-slow.video.urllist
    cat "$plist" \
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
#if [ -e .generate-scenes -a -e tmplists/scenes.mp3.tmplist ]; then
#    echo "... scenes (Red)" >&2
#    cat tmplists/scenes.mp3.tmplist \
#	| sed -e '/:I\.3/!{;/Gold/d;}' \
#        > scenes-red.mp3.urllist
#fi

### score PDFs

if [ -n "$INDEX_PDF" ]; then
    echo "... score" >&2

    ./plinks.pl --base "$base_uri" "$INDEX_PDF" \
        | sed  -e '/\.pdf$/I!d' \
               -e '/^[^	]*score/I!d;/LibrettoBook/d;/OPERA-PARTY/d' \
               -e 's/^[^	]*	//' \
               -e 's/^[^	]*	//' > score.pdf.urllist
fi
