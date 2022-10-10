#!/bin/bash

DO_WIPE=
DO_CHECK_LINKS=
INDEX_CHORUS=
INDEX_DEMO=
INDEX_ORCH=
INDEX_PDF=
INDEX_VIDEO=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --wipe)     DO_WIPE=yes; shift ;;
        --check-links)
                    DO_CHECK_LINKS=yes; shift ;;
        --chorus)   INDEX_CHORUS="$2"; shift; shift ;;
        --demo)     INDEX_DEMO="$2"; shift; shift ;;
        --orch)     INDEX_ORCH="$2"; shift; shift ;;
        --pdf)      INDEX_PDF="$2"; shift; shift ;;
        --video)    INDEX_VIDEO="$2"; shift; shift ;;
        *)
            echo "Unknown argument: '$1'" >&2; exit 1 ;;
    esac
done

DIR=tmplists
rm -f *.tmplist "$DIR"/*.tmplist "$DIR"/.*.tmplist
if [ -n "$DO_WIPE" ]; then rm -f *.urllist "$DIR"/*.urllist; fi
if [ ! -d "$DIR" ]; then mkdir "$DIR"; fi

base_uri=http://www.familyopera.org/drupal/DUMMY/

#do_generate_zip=
#if [ -e .generate-zip ]; then do_generate_zip=yes; fi
#do_generate_cd=
#if [ -e .generate-cd ]; then do_generate_cd=yes; fi
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
        ./plinks.pl -h1 -hb -li -plt -lt -lb -t -la -ml \
                    --base "$base_uri" "$index" > "$plist"
    fi
    echo "$plist"
}

tlist () {
    local index="$1"; shift
    local tlist="${index##*/}"; tlist="$DIR/${tlist%%.html}.t.tmplist"
    if [ ! -e "$tlist" ]; then
        echo "... $tlist" >&2
        ./print-table-links.pl -h1 -hb -nc -nl -rb -eb -t -ea -ra -sep '~' -ol -ml \
                               --base "$base_uri" "$index" > "$tlist"
    fi
    echo "$tlist"
}

handle_flat_section () {
    local plist="$1"; shift
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local less_indented="$1"; shift
    local prev_line="$1"; shift
    local curr_line="$1"; shift
    local link="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local out_tag=out_file
    cat "$plist" \
        | sed -e '/\.mp3$/I!d' \
              -e '/^'"$heading1"'/I!d' \
              -e 's,^[^	]*	,,' \
              -e '/^'"$bold_or_heading"'/I!d' \
              -e 's,^[^	]*	,,' \
              -e '/^'"$less_indented"'/I!d' \
              -e 's,^[^	]*	,,' \
              -e '/^'"$prev_line"'/I!d' \
              -e 's,^[^	]*	,,' \
              -e '/^'"$curr_line"'/I!d' \
              -e 's,^[^	]*	,,' \
              -e 's,^[0-9]*\.  *,,' \
              -e '/^[^	]*	'"$link"'/I!d' \
              -e 's/^\([^	]*[^ 	]\) *	/\1	/' \
              -e 's/^\([^	]*\)	/\1 	/' \
              -e 's/^  *	/	/' \
              -e 's/^\([^	]*\)( 	/\1(	/' \
              -e 's/^\([^	]*\)	/\1/' \
              -e 's/^\([^	]*\)	/\1	 /' \
              -e 's/^\([^	]*\)	  *	/\1		/' \
              -e 's/^\([^	]*\)	  *)/\1	)/' \
              -e 's/^\([^	]*\)	/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[:\*\?"<>|]/\1/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/^\([^	]*\)[’]/\1'\''/' \
              -e 's/   */ /g' -e 's/^  *//' -e 's/  *	/	/g' \
              -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
              -e 's,\xe2\x80\x99,'\'',g' \
              -e ''
}

extract_flat_satb_sections () {
    local plist="$1"; shift
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift
    local voice less_indented
    for voice in 'soprano' 'alto' 'tenor' 'bass'; do
        local short="$(echo "$voice" \
                       | sed -e 's/^\(.\)[^ ]* \?/\1/;y/SATBC/satbc/')"
        for less_indented in "$@"; do
            less_indented_pre="$less_indented "
            less_indented_pre="${less_indented_pre## }"
            handle_flat_section "$plist" \
                                "$heading1" "$bold_or_heading" \
                                "$less_indented" '' '' \
                                '[^	]* '"$voice" \
                                "$files_prefix${short^^} $less_indented_pre" \
                                "$files_suffix"
        done > "$DIR"/"$file-$short".mp3.tmplist
    done
}

extract_flat_section_links () {
    local plist="$1"; shift
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local link="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift
    handle_flat_section "$plist" "$heading1" "$bold_or_heading" \
                        '' '' '' "$link" \
                        "$files_prefix" "$files_suffix" \
                        > "$DIR"/"$file".mp3.tmplist
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
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local part="$1"; shift
    local column="$1"; shift
    local line="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local text_style=replace
    #local text_style=prepend
    local out_tag=out_file
    if [ "$text_style" = prepend ]; then
        out_tag=out_file_prefix
        files_suffix="$files_suffix "
    fi

    sed -e '/\.mp3$/I!d' \
        -e '/^'"$heading1"'/I!d' \
        -e 's,^[^	]*	,,' \
        -e '/^'"$bold_or_heading"'/I!d' \
        -e 's,^[^	]*	,,' \
        -e '/^'"$column"'	/!d' `# select columns to extract` \
        -e 's,^\(3	[^	]*	\)\([^	]*	\),\1pan \2w ,' \
| tee /tmp/XYZZY."$column"."$heading1"."$bold_or_heading"."$part" | sed \
        -e 's/^[^	]*	//' \
        -e '/^'"$line"'	/!d' `# select columns to extract` \
        -e 's/^[^	]*	//' \
        -e '/^'"$part"'/I!d' \
        `# -e 's,^[^	]*	,,'` \
        -e 's/^\(pan \)\?Act \([^	 ]*\) Scene \([^	 ]*\)/\1\2.\3/I' \
        -e 's/^\(pan \)\?Scene \([^ 	]*\)/\1sc\2/I' \
        `# use the scene "#.#" number from filename if available:` \
        -e 's/^\(pan \)\?sc\([1-9][0-9]*\)\([^0-9.].*\/[-_A-Za-z]*[-_]\)\(\2\.[1-9][0-9]*\)\([-_][^\/	]*\)$/\1sc\4\3\4\5/' \
        -e 's/	/, /' \
        -e 's/	/ /' \
        -e 's/	/ /' \
        -e 's/^\([^	]*\)	\([^	]*\)	/\1, \2	/' \
        -e 's/^\([^	]*\),[ ~]*	/\1	/' \
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
        -e 's/, *,/,/;s/, *,/,/' -e 's/  *,/,/g;s/, *	/	/' \
        -e 's/^\([^	]*\)	\(.*\)$/\2	'"$out_tag:$files_prefix"'\1'"$files_suffix"'/' \
        -e 's,\xe2\x80\x99,'\'',g' \
        -e ''
}

extract_table_section () {
    local tlist="$1"; shift
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local part="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    cat "$tlist" \
        | process_table_section_columns \
              "$heading1" "$bold_or_heading" "$part" \
              '[23]' '[^	]*' "$files_prefix" "$files_suffix" \
              > "$DIR"/"$file".mp3.tmplist
}

extract_table_satb_sections () {
    local tlist="$1"; shift
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local part="$1"; shift
    local list_prefix="$1"; shift
    local list_suffix="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    for voice in 'soprano' 'alto' 'tenor' 'bass'; do
        short="`echo "$voice" | sed -e 's/^\(.\)[^ ]* \?/\1/;y/SATBC/satbc/'`"
        extract_table_section "$tlist" \
            "$heading1" "$bold_or_heading" "$part[^	]*$voice" \
            "$list_prefix$short$list_suffix" \
            "$files_prefix`echo "$short" | sed -e 'y/satb/SATB/'` " \
            "$files_suffix"
    done
}

extract_table_demo () {
    local tlist="$1"; shift
    local heading1="$1"; shift
    local bold_or_heading="$1"; shift
    local part="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    cat "$tlist" \
        | process_table_section_columns \
              "$heading1" "$bold_or_heading" "$part" \
              '1' '0\?' "$files_prefix" "$files_suffix" \
        | sed -e 's!:[^,/][^,]*, *!:'"$files_prefix"'!; s!,[^,]*$! (Demo)!' \
              `# hack file names` \
              > "$DIR"/"$file".mp3.tmplist
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
    extract_flat_satb_sections "$(plist "$INDEX_CHORUS")" \
                               'Space Opera' 'Chorus' 'so-chorus' 'SO ' '' \
                               "I'm the Best" "Jabba Jive" "Vader's Orders"

    extract_flat_section_links "$(plist "$INDEX_CHORUS")" \
                               'Space Opera' 'Chorus' 'Bith' 'bith' 'SO ' ''

    extract_table_satb_sections "$(tlist "$INDEX_CHORUS")" \
                                'Cutlass Crew' 'Chorus' '' \
                                'cc-chorus-' '' 'CC ' ''

    extract_table_section "$(tlist "$INDEX_CHORUS")" \
                          'Cutlass Crew' '[^	]*\(solos\|dutch\)' '' \
                          'cc-all-supporting' 'CC ' ''

    for s in tavernkeeper 'reveler 1' 'reveler 2' 'reveler 3' 'reveler 4' \
             'captain gouda' 'henk' 'schenk' 'denk'  ; do
        f="${s// /-}"
        cat "$DIR"/cc-all-supporting.mp3.tmplist \
            | grep -i '\<'"$s"'\(,\| *&\)' \
            | uniq \
                  > "$DIR"/"$f".mp3.tmplist
    done
    cat "$DIR"/cc-all-supporting.mp3.tmplist \
        | grep -i '\<\(henk\|schenk\|denk\|\)\(,\| *&\)' \
        | uniq \
              > "$DIR"/henk-schenk-denk.mp3.tmplist

    extract_table_section "$(tlist "$INDEX_CHORUS")" \
                          'Cutlass Crew' '' 'Lady Mary' 'lady-mary' 'CC ' ''

    extract_table_satb_sections "$(tlist "$INDEX_CHORUS")" \
                                'The Coronation of Esther' 'Chorus' '' \
                                'est-chorus-' '' 'Est ' ''

    extract_table_satb_sections "$(tlist "$INDEX_CHORUS")" \
                                'Springtime for Haman' 'Chorus' '' \
                                'sh-chorus-' '' 'SH ' ''
fi

if [ -n "$INDEX_DEMO" ]; then
    extract_flat_section_links "$(plist "$INDEX_DEMO")" \
                               'Space Opera' 'DEMOS' \
                               'Demo' 'demo-so' 'SO ' ''
    extract_table_demo "$(tlist "$INDEX_CHORUS")" \
                       'Cutlass Crew' 'Chorus' '[^	]*soprano' \
                       'demo-cc' 'CC ' ''
    extract_flat_section_links "$(plist "$INDEX_DEMO")" \
                               'The Coronation of Esther' 'DEMOS' \
                               'Demo' 'demo-est' 'Est ' ''
    extract_flat_section_links "$(plist "$INDEX_DEMO")" \
                               'Springtime for Haman' 'DEMOS' \
                               'Demo' 'demo-sh' 'SH ' ''
fi
if [ -n "$INDEX_ORCH" ]; then
    extract_flat_section_links "$(plist "$INDEX_ORCH")" \
                               'Space Opera' 'DEMOS' \
                               'Orchestra' 'orchestra-so' 'SO ' ''
    extract_flat_section_links "$(plist "$INDEX_ORCH")" \
                               'Cutlass Crew' 'DEMOS' \
                               'Accompaniment' 'orchestra-cc' 'Est ' ''
    extract_flat_section_links "$(plist "$INDEX_ORCH")" \
                               'The Coronation of Esther' 'DEMOS' \
                               'Orchestra' 'orchestra-est' 'Est ' ''
    extract_flat_section_links "$(plist "$INDEX_ORCH")" \
                               'Springtime for Haman' 'DEMOS' \
                               'Orchestra' 'orchestra-sh' 'SH ' ''
fi

#if [ -n "$do_generate_all_voices" -a -n "$INDEX_CHORUS" ]; then
#    cat "$DIR"/{s,a,ac,t,b}-*.mp3.tmplist | sed \
#        -e '/NOOP/d' \
#        > X-all-voices.mp3.urllist
#fi

#if [ -n "$do_generate_all_supporting" -a -n "$INDEX_CHORUS" ]; then
#    cat "$DIR"/all-supporting.mp3.tmplist | sed \
#        -e '/NOOP/d' \
#        > X-all-supporting.mp3.urllist
#fi

#if [ -n "$do_generate_all_solos" -a -n "$INDEX_SOLO" ]; then
#    cat "$DIR"/all-solos.mp3.tmplist | sed \
#        -e '/NOOP/d' \
#        > X-all-solos.mp3.urllist
#fi

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

### Katarina (Soprano, Lady Mary, Bith 1)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    true > Katarina.mp3.urllist
    cat "$DIR"/bith.mp3.tmplist \
        | sed \
            -e '/Bith 1/I!d' \
        >> Katarina.mp3.urllist
    cat "$DIR"/bith.mp3.tmplist \
        | sed \
            -e '/Bith 1/Id' \
        >> Katarina.mp3.urllist
    cat "$DIR"/so-chorus-a.mp3.tmplist \
        | sed \
            -e '/Jabba/I!d' \
        >> Katarina.mp3.urllist
    cat "$DIR"/lady-mary.mp3.tmplist \
        >> Katarina.mp3.urllist
    cat "$DIR"/est-chorus-s.mp3.tmplist \
        >> Katarina.mp3.urllist
fi

### Luka (Alto, Dutch Crew [Henk?], Bith 2)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    true > Luka.mp3.urllist
    cat "$DIR"/bith.mp3.tmplist \
        | sed \
            -e '/Bith 2/I!d' \
        >> Luka.mp3.urllist
    cat "$DIR"/bith.mp3.tmplist \
        | sed \
            -e '/Bith 1/I!d' \
        >> Luka.mp3.urllist
    cat "$DIR"/so-chorus-a.mp3.tmplist \
        | sed \
            -e '/Jabba/I!d' \
        >> Luka.mp3.urllist
    cat "$DIR"/henk-schenk-denk.mp3.tmplist \
        >> Luka.mp3.urllist
    cat "$DIR"/est-chorus-a.mp3.tmplist \
        >> Luka.mp3.urllist
fi

### Abbe (Alto, Chamberlain, Reveler 1, Vader's Orders ST)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    true > Abbe.mp3.urllist
    cat "$DIR"/so-chorus-a.mp3.tmplist \
        | sed \
            -e 's/both include/includes/' \
            -e '/ panned right/{;s/ panned right//;s/SO A/SO A pan/;}' \
        >> Abbe.mp3.urllist
    cat "$DIR"/reveler-1.mp3.tmplist \
        | sed \
            -e '/1583/!d;/reprise/Id' \
        >> Abbe.mp3.urllist
    cat "$DIR"/cc-chorus-a.mp3.tmplist \
        | sed \
            -e '/revelers/I!d;/1583/{;/reprise/Id;}' \
        >> Abbe.mp3.urllist
    cat "$DIR"/reveler-1.mp3.tmplist \
        | sed \
            -e '/1583/!d;/reprise/I!d' \
        >> Abbe.mp3.urllist
    cat "$DIR"/cc-chorus-a.mp3.tmplist \
        | sed \
            -e '/revelers/I!d;/1583/!d;/reprise/I!d' \
        >> Abbe.mp3.urllist
    cat "$DIR"/est-chorus-a.mp3.tmplist \
        >> Abbe.mp3.urllist
fi

### bert (Bass, Reveler 2+4, Vader's Orders ST)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    true > bert.mp3.urllist
    cat "$DIR"/so-chorus-b.mp3.tmplist \
        | sed \
            -e 's/both include/includes/' \
            -e '/ panned right/{;s/ panned right//;s/SO B/SO B pan/;}' \
        >> bert.mp3.urllist
    cat "$DIR"/reveler-2.mp3.tmplist \
        | sed \
            -e '/1583/!d;/reprise/Id' \
        >> bert.mp3.urllist
    cat "$DIR"/cc-chorus-b.mp3.tmplist \
        | sed \
            -e '/revelers/I!d;/1583/!d;/reprise/Id;/141-158/d' \
        >> bert.mp3.urllist
    cat "$DIR"/reveler-4.mp3.tmplist \
        | sed \
            -e '/1583/!d;/reprise/Id' \
        >> bert.mp3.urllist
    cat "$DIR"/cc-chorus-b.mp3.tmplist \
        | sed \
            -e '/revelers/I!d;/1583/!d;/reprise/Id;/141-158/!d' \
        >> bert.mp3.urllist
    cat "$DIR"/cc-chorus-b.mp3.tmplist \
        | sed \
            -e '/revelers/I!d;/1583/d' \
        >> bert.mp3.urllist
    cat "$DIR"/reveler-2.mp3.tmplist \
        | sed \
            -e '/1583/!d;/reprise/I!d' \
        >> bert.mp3.urllist
    cat "$DIR"/cc-chorus-b.mp3.tmplist \
        | sed \
            -e '/revelers/I!d;/1583/!d;/reprise/I!d' \
        >> bert.mp3.urllist
    cat "$DIR"/reveler-4.mp3.tmplist \
        | sed \
            -e '/1583/!d;/reprise/I!d' \
        >> bert.mp3.urllist
    cat "$DIR"/est-chorus-b.mp3.tmplist \
        >> bert.mp3.urllist
fi

### generating generic zip files
# for those, we keep David's original file names...

### burning CDs for people

#if [ -n "$do_generate_cd" -a -n "$INDEX_CHORUS" -a -n "$INDEX_SOLO" ]; then
#    #cat "$DIR"/s-chorus.mp3.tmplist | sed \
#    #    -e '/Misrule-sop/d;/Malley-sop-2/{;/2-hi/!d;};/Cornwall-sop-2/d' \
#    #    -e '/Epilogue-part2-sop/d' \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-s1-chorus.mp3.urllist
#    #cat "$DIR"/s-chorus.mp3.tmplist | sed \
#    #    -e '/Misrule-desc/d;/Malley-sop-2-hi/d;/Cornwall-desc/d' \
#    #    -e '/Epilogue-part2-desc/d' \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-s2-chorus.mp3.urllist
#    #cat "$DIR"/a-chorus.mp3.tmplist | sed \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-a-chorus.mp3.urllist
#    #cat "$DIR"/t-chorus.mp3.tmplist | sed \
#    #    -e '/Malley-tenor-2-lo/d' \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-t1-chorus.mp3.urllist
#    #cat "$DIR"/t-chorus.mp3.tmplist | sed \
#    #    -e '/Malley-tenor-2-hi/d' \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-t2-chorus.mp3.urllist
#    #cat "$DIR"/b-chorus.mp3.tmplist | sed \
#    #    -e '/WomenOfWar-RevelerBassLo/d;/1583Reprise-Crew-bass-lo/d' \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-b1-chorus.mp3.urllist
#    #cat "$DIR"/b-chorus.mp3.tmplist | sed \
#    #    -e '/WomenOfWar-RevelerBassHi/d;/1583Reprise-Crew-bass-hi/d' \
#    #    -e '/Grooms/d;/Cabin Boys/d;/Seamstresses/d;/Ladies-in-Waiting/d' \
#    #    -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#    #    > XX-cd-b2-chorus.mp3.urllist
#    if false; then
#        cat "$DIR"/a-chorus.mp3.tmplist | sed \
#            -e '/Master/I,$d' \
#            -e '/Grooms/d;/Cabin Boys/d;/Ladies-in-Waiting/d' \
#            -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#            > X-cd-joanne-nicklas.mp3.urllist
#        cat "$DIR"/jailers.mp3.tmplist | sed \
#            -e '/Crackity/I!d' \
#            -e '/, \(w \)\?\(Amphillis\|lower\)$/I!d' \
#            -e 's/Amphillis,/ Amphillis,/;s/  / /' \
#            -e 's/ \(Amphillis.*\), \(w \)\?\(Amphillis\|lower\)$/ \2\1/' \
#            >> X-cd-joanne-nicklas.mp3.urllist
#        cat "$DIR"/jailers.mp3.tmplist | sed \
#            -e '/Crackity/Id;/Prosecution/Id' \
#            -e '/, \(w \)\?\(jailers low\)$/I!d' \
#            >> X-cd-joanne-nicklas.mp3.urllist
#        #cat "$DIR"/a-chorus.mp3.tmplist | sed \
#        #    -e '/Prosecution/I,$!d;/Defense/I,$d' \
#        #    -e '/Lawyers/d' \
#        #    >> X-cd-joanne-nicklas.mp3.urllist
#        cat "$DIR"/jailers.mp3.tmplist | sed \
#            -e '/Prosecution/I!d' \
#            >> X-cd-joanne-nicklas.mp3.urllist
#        cat "$DIR"/a-chorus.mp3.tmplist | sed \
#            -e '/Defense/I,$!d' \
#            -e '/Grooms/d;/Cabin Boys/d;/Ladies-in-Waiting/d' \
#            -e '/Lawyers/d;/Dowland/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#            >> X-cd-joanne-nicklas.mp3.urllist
#    fi
#    if false; then
#        cat "$DIR"/a-chorus.mp3.tmplist | sed \
#            -e '/Grooms/d;/Cabin Boys/d;/Ladies-in-Waiting/d' \
#            -e '/Lawyers/d;/, \(w \)\?\(Cutlass \)\?Crew/d' \
#            > X-cd-heather-barney.mp3.urllist
#    fi
#fi

#####  video
#if [ -n "$INDEX_VIDEO" ]; then
#    plist="$(plist "$INDEX_VIDEO")"
#    cat "$plist" \
#        | sed -e '/\.mp4$/I!d' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' \
#              -e '/MIRROR/I!d;/SLOW/Id' \
#              > mirror-fullsp.video.urllist
#    cat "$plist" \
#        | sed -e '/\.mp4$/I!d' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' \
#              -e '/MIRROR/Id;/SLOW/Id' \
#              > regular-fullsp.video.urllist
#    cat "$plist" \
#        | sed -e '/\.mp4$/I!d' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' \
#              -e '/MIRROR/I!d;/SLOW/I!d' \
#              > mirror-slow.video.urllist
#    cat "$plist" \
#        | sed -e '/\.mp4$/I!d' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' \
#              -e '/MIRROR/Id;/SLOW/I!d' \
#              > regular-slow.video.urllist
#    cat "$plist" \
#        | sed -e '/\.pdf$/I!d' \
#              -e '/sponsorship/Id' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' -e 's/^[^	]*	//' \
#              -e 's/^[^	]*	//' \
#              > blocking.video.urllist
#fi

### demo MP3s
if [ -n "$do_generate_demo" ]; then
    echo "... demo" >&2
    for i in so cc est sh; do cat tmplists/demo-"$i".mp3.tmplist; done \
        > demo.mp3.urllist
    if [ ! -s demo.mp3.urllist ]; then rm -f demo.mp3.urllist; fi
fi

### orchestra-only MP3s
if [ -n "$do_generate_orchestra" -a -e tmplists/orchestra.mp3.tmplist ]; then
    echo "... orchestra" >&2
    for i in so cc est sh; do cat tmplists/orchestra-"$i".mp3.tmplist; done \
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

### blocking PDFs

if [ -n "$INDEX_VIDEO" ]; then
    echo "... blocking" >&2

    ./plinks.pl --base "$base_uri" "$INDEX_VIDEO" \
        | sed  -e '/\.pdf$/I!d' \
               -e 's/^[^	]*	//' \
               -e 's/^[^	]*	//' > blocking.pdf.urllist
fi
