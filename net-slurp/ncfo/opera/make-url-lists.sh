#!/bin/bash

DO_WIPE=
DO_CHECK_LINKS=
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
        --check-links)
                    DO_CHECK_LINKS=yes; shift ;;
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

do_generate_zip=
if [ -e .generate-zip ]; then do_generate_zip=yes; fi
do_generate_cd=
if [ -e .generate-cd ]; then do_generate_cd=yes; fi
do_generate_demo=
if [ -e .generate-demo ]; then do_generate_demo=yes; fi
do_generate_orchestra=
if [ -e .generate-orchestra ]; then do_generate_orchestra=yes; fi
do_generate_scenes=
if [ -e .generate-scenes ]; then do_generate_scenes=yes; fi

do_generate_all_voices=
if [ -e .generate-all-voices ]; then do_generate_all_voices=yes; fi
do_generate_all_supporting=
if [ -e .generate-all-supporting ]; then do_generate_all_supporting=yes; fi
do_generate_all_solos=
if [ -e .generate-all-solos ]; then do_generate_all_solos=yes; fi

if [ -n "$DO_CHECK_LINKS" ]; then
    do_generate_cd=yes; do_generate_demo=yes
    do_generate_orchestra=yes; do_generate_scenes=yes
    do_generate_all_voices=yes; do_generate_all_supporting=yes
    do_generate_all_solos=yes
fi

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
        ./print-table-links.pl -hb -nc -rb -eb -t -ea -ra -sep '~' -ol \
                               --base "$base_uri" "$index" > "$tlist"
    fi
    echo "$tlist"
}

get_table_mp3_sections () {
    local tlist="$1"; shift
    sed -e '/\.mp3$/I!d;s/	.*//' "$tlist" | sort | uniq
}

get_table_section_column () {
    local tlist="$1"; shift
    local section="$1"; shift
    local column="$1"; shift

    local skips=()
    local i
    for ((i=0; i<"$column"; ++i)); do
        skips+=(-e 's/^[^~	]*[~	]//')
    done

    cat "$tlist" \
        | sed -e '/\.mp3$/I!d;/^'"$section"'/I!d' \
              -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              "${skips[@]}" \
              -e 's/[~	].*//' \
              "$tlist" \
        | sort | uniq
}

filter_table_column () {
    local column="$1"; shift
    local value="$1"; shift

    column=$((column+3))  # first awk column is 1, first data column is awk 3
    awk -F '[~	]' -v value="$value" '($'"$column"' == value)'
}

process_table_section_columns () {
    local section="$1"; shift
    local column="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local text_style=replace
    #local text_style=prepend
    local out_tag=out_file
    if [ "$text_style" = prepend ]; then
        out_tag=out_file_prefix
        files_suffix="$files_suffix "
    fi

    sed -e '/\.mp3$/I!d;/^'"$section"'/I!d' \
        -e 's/^[^	]*	//' \
        -e '/^'"$column"'	/!d' `# select columns to extract` \
        -e 's,^\(3	\)\([^	]*	\),\1pan \2w ,' \
        -e 's/^[^	]*	//' \
        -e 's/^\(pan \)\?Act \([^	 ]*\) Scene \([^	 ]*\)/\1\2.\3/I' \
        -e 's/^\(pan \)\?Scene \([^ 	]*\)/\1sc\2/I' \
        `# use the scene "#.#" number from filename if available:` \
        -e 's/^\(pan \)\?sc\([1-9][0-9]*\)\([^0-9.].*\/[-_A-Za-z]*[-_]\)\(\2\.[1-9][0-9]*\)\([-_][^\/	]*\)$/\1sc\4\3\4\5/' \
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
        -e 's,\xe2\x80\x99,'\'',g'
}

extract_table_section () {
    local tlist="$1"; shift
    local section="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    cat "$tlist" \
    | process_table_section_columns \
          "$section" '[23]' "$files_prefix" "$files_suffix" \
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

extract_solo_section () {
    local tlist="$1"; shift
    local section="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    extract_table_section "$tlist" "$section" "$file" \
                          "$files_prefix" "$files_suffix"

    cat "$DIR"/"$file".mp3.tmplist >> "$DIR"/all-solos.mp3.tmplist
}

prepare_link_check () {
    local index="$1"; shift
    local base="${index##*/}"; base="$DIR/${base%%.html}"
    echo "... $base.lc*.tmplist" >&2
    ./plinks.pl --base "$base_uri" "$index" > "$base.lc0.tmplist"
    sed -ne '/\.mp3$/Ip' "$base.lc0.tmplist" > "$base.lc-mp3.tmplist"
    sed -ne '/\.pdf$/Ip' "$base.lc0.tmplist" > "$base.lc-pdf.tmplist"
    sed -ne '/\.mp4$/Ip' "$base.lc0.tmplist" > "$base.lc-video.tmplist"
    sed -e '/\.mp3$/Id;/\.pdf$/Id;/\.mp4$/Id' "$base.lc0.tmplist" \
        > "$base.lc1.tmplist"
    cat "$base.lc1.tmplist" | sed \
        -e '\,^#,Id' \
        -e '\,^https\?://www.drupal.org,Id' \
        -e '\,^https\?://thaliarealtor.com,Id' \
        -e '\,^https\?://thaliarealtor.com,Id' \
        -e '\,^https\?://www.exceptionallives.org,Id' \
        -e '\,^https\?://www.portersquarebooks.com,Id' \
        -e '\,^https\?://familyopera.org/mailinglist.html$,d' \
        -e '\,^https\?://www.familyopera.org/drupal/\?$,d' \
        -e '\,^https\?://www.familyopera.org/drupal/[^\./][^\./]*/\?$,d' \
        -e '\,^https\?://www.familyopera.org/drupal/node/[1-9][0-9]*$,d' \
        -e '\,^https\?://www.familyopera.org/drupal/node/[^\./][^\./]*/\?$,d' \
        -e '\,^https\?://www.familyopera.org/drupal/user/logout,d' \
        > "$base.lcE.tmplist"
    if [ -s "$base.lcE.tmplist" ]; then
        sed -e 's/^/LNK unexpected: /' "$base.lcE.tmplist" >&2
    fi
}


if [ -n "$INDEX_CHORUS" ]; then
    extract_satb_sections "$(tlist "$INDEX_CHORUS")" '' ' MP3s' '' '-chorus'

    extract_table_section "$(tlist "$INDEX_CHORUS")" "SUPPORTING" \
                          "all-supporting"
    for s in clement thomasina walter myles edmund \
             'cabin boy' \
             tavernkeeper 'reveler 1' 'reveler 2' 'reveler 3' 'reveler 4' \
             'captain gouda' 'henk' 'schenk' 'denk' \
             jolye dowland \
             soldier yeoman ; do
        f="${s// /-}"
        cat "$DIR"/all-supporting.mp3.tmplist \
            | grep -i '\<'"$s"'\(,\| *&\)' \
            | uniq \
             > "$DIR"/"$f".mp3.tmplist
    done
fi

if [ -n "$INDEX_SOLO" ]; then
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Lady Mary" "lady-mary"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Sir Digory Piper" "piper"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Queen" "queen"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Sir Julius Caesar" "caesar"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Sir John K" "sir-john"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Parry" "parry"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Betty" "betty"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Ned" "ned"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Nan" "nan"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Cicely" "cicely"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Oswald" "oswald+susan"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Don Diego" \
                         "diego+felipe+leonora"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Paco, Pepe" \
                         "paco+pepe+pio+juancho"
    extract_solo_section "$(tlist "$INDEX_SOLO")" "Jeffries, Margery, Dorcas" \
                         "jailers"
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


if [ -n "$do_generate_all_voices" -a -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/{s,a,ac,t,b}-*.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > X-all-voices.mp3.urllist
fi

if [ -n "$do_generate_all_supporting" -a -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/all-supporting.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > X-all-supporting.mp3.urllist
fi

if [ -n "$do_generate_all_solos" -a -n "$INDEX_SOLO" ]; then
    cat "$DIR"/all-solos.mp3.tmplist | sed \
        -e '/NOOP/d' \
        > X-all-solos.mp3.urllist
fi

if [ -n "$DO_CHECK_LINKS" ]; then
    for i in "$INDEX_CHORUS" "$INDEX_SOLO" "$INDEX_DEMO" "$INDEX_ORCH" \
             "$INDEX_SCENE" "$INDEX_PDF" "$INDEX_VIDEO"; do
        if [ -n "$i" ]; then
            prepare_link_check "$i"
        fi
    done
    for i in mp3 pdf video; do
        sort "$DIR"/*."lc-$i.tmplist" | uniq > X-link-check."$i".tmplist
    done
fi

### Katarina (Clement/soprano 1)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/s-chorus.mp3.tmplist | sed \
        -e '/Grace O.Malley/I,$d' \
        -e '/Misrule-sop/Id' \
       > Katarina.mp3.urllist
    cat "$DIR"/clement.mp3.tmplist | sed \
        -e 's/\(out_file:\)\(.*\)Clement, /\1Clement \2/' \
        >> Katarina.mp3.urllist
    cat "$DIR"/s-chorus.mp3.tmplist | sed \
        -e '/Epiphany Cake/I,$!d' \
        -e '/Cornwall-sop-2/Id' \
        -e '/Epilogue-part2-sop/Id' \
        >> Katarina.mp3.urllist
fi

### Luka (*enk/soprano 2)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/s-chorus.mp3.tmplist | sed \
        -e '/Aberdeen/I,$d' -e '/Ballad.*Reprise/I,$d' \
        -e '/Misrule-desc/Id' \
        -e '/Malley-sop-2-hi/Id' \
        -e '/Cornwall-desc/Id' \
        > Luka.mp3.urllist
    cat "$DIR"/henk.mp3.tmplist | sed \
        -e 's/\(out_file:\)\(.*\)Henk, /\1Henk \2/' \
        >> Luka.mp3.urllist
    cat "$DIR"/schenk.mp3.tmplist | sed \
        -e 's/\(out_file:\)\(.*\)Schenk, /\1Schenk \2/' \
        >> Luka.mp3.urllist
    cat "$DIR"/denk.mp3.tmplist | sed \
        -e 's/\(out_file:\)\(.*\)Denk, /\1Denk \2/' \
        >> Luka.mp3.urllist
    cat "$DIR"/s-chorus.mp3.tmplist | sed \
        -e '/Ballad.*Reprise/I,$!d' \
        -e '/Epilogue-part2-desc/Id' \
        >> Luka.mp3.urllist
fi

### bert (Walter/tenor)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/t-chorus.mp3.tmplist | sed \
        -e '/Grace O.Malley/I,$d' \
       > bert.mp3.urllist
    cat "$DIR"/walter.mp3.tmplist | sed \
        -e 's/\(out_file:\)\(.*\)Walter, /\1Walter \2/' \
        >> bert.mp3.urllist
    cat "$DIR"/t-chorus.mp3.tmplist | sed \
        -e '/Grace O.Malley/I,$!d' \
        -e '/Malley-tenor-2-lo/Id' \
        >> bert.mp3.urllist
fi

### Abbe (???)
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

### generating zip files
# for those, we keep David's original file names...

if [ -n "$do_generate_zip" ]; then
    for i in "$INDEX_CHORUS" "$INDEX_SOLO"; do
        if [ -n "$i" ]; then
            get_table_mp3_sections "$(tlist "$i")" \
            | while read -r section; do
                base="`echo "$section" \
                       | perl -CSDA -lpe 's/\b([A-Z]+)\b/\u\L\1/g;s,/,,g'`"
                cat "$(tlist "$i")" \
                    | process_table_section_columns "$section" '.*' '' '' \
                    | sed -e 's/	.*$//' \
                          > "$base".mp3zip.urllist
                # some links may be repeated in the list, but that's OK
            done
        fi
    done

    if [ -n "$INDEX_CHORUS" ]; then
        section="SUPPORTING"
        get_table_section_column "$(tlist "$INDEX_CHORUS")" "$section" 1 \
        | while read -r who; do
            base="$who"
            cat "$(tlist "$INDEX_CHORUS")" \
                | filter_table_column 1 "$who" \
                | process_table_section_columns "$section" '.*' '' '' \
                | sed -e 's/	.*$//' \
                      > "$base".mp3zip.urllist
            # some links may be repeated in the list, but that's OK
        done
    fi
fi

### burning CDs
if [ -n "$do_generate_cd" -a -n "$INDEX_CHORUS" ]; then
    : ##cp "$DIR"/s-chorus.mp3.tmplist s-chorus.mp3.urllist
    : ##cp "$DIR"/a-chorus.mp3.tmplist a-chorus.mp3.urllist
    : ##cp "$DIR"/t-chorus.mp3.tmplist t-chorus.mp3.urllist
    : ##cp "$DIR"/b-chorus.mp3.tmplist b-chorus.mp3.urllist
fi

#####  video
if [ -n "$INDEX_VIDEO" ]; then
    plist="$(plist "$INDEX_VIDEO")"
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              -e '/MIRROR/I!d;/SLOW/Id' \
              > mirror-fullsp.video.urllist
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              -e '/MIRROR/Id;/SLOW/Id' \
              > regular-fullsp.video.urllist
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              -e '/MIRROR/I!d;/SLOW/I!d' \
              > mirror-slow.video.urllist
    cat "$plist" \
        | sed -e '/\.mp4$/I!d' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
              -e 's/^[^	]*	//' \
              -e '/MIRROR/Id;/SLOW/I!d' \
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
if [ -n "$do_generate_demo" -a -e tmplists/demo.mp3.tmplist ]; then
    echo "... demo" >&2
    cat tmplists/demo.mp3.tmplist \
        > demo.mp3.urllist
fi

### orchestra-only MP3s
if [ -n "$do_generate_orchestra" -a -e tmplists/orchestra.mp3.tmplist ]; then
    echo "... orchestra" >&2
    cat tmplists/orchestra.mp3.tmplist \
        > orchestra.mp3.urllist
fi
#if [ -n "$do_generate_scenes" -a -e tmplists/scenes.mp3.tmplist ]; then
#    echo "... scenes (Red)" >&2
#    cat tmplists/scenes.mp3.tmplist \
#        | sed -e '/:I\.3/!{;/Gold/d;}' \
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
