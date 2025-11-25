#!/bin/bash

source "$(dirname "$0")/_uri.sh"

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

base_uri="${base_uri}/DUMMY"

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

force_https=yes

use_tables=

# 'AC' is the melody part for Weedpatch
voice_parts=('Soprano' 'Alto' 'AC' 'Tenor' 'Bass')

plist () {
    local index="$1"; shift
    local plist="${index##*/}"; plist="$DIR/${plist%%.html}.p.tmplist"
    local pslist="${plist%%.p.tmplist}.ps.tmplist"
    if [ "$plist" = "$DIR/.p.tmplist" ]; then
        echo "... $plist (plist) has no name for index $index" >&2
    elif [ ! -e "$plist" ]; then
        echo "... $plist (plist)" >&2
        ./plinks.pl --show-bold-or-heading --show-less-indented \
                    --show-previous-line-text --show-line-text \
                    --show-line-before-link --show-text \
                    --show-line-after-link --merge-links \
                    --base "$base_uri" "$index" > "$plist"
        if [[ -n "$force_https" ]]; then
            echo "... $pslist (plist+https)" >&2
            sed -e 's,	http\(://\(www.\)\?familyopera.org/\),	https\1,g' \
                < "$plist" > "$pslist"
        fi
    fi
    if [[ -z "$force_https" ]]; then
        echo "$plist"
    else
        echo "$pslist"
    fi
}

tlist () {
    local index="$1"; shift
    local tlist="${index##*/}"; tlist="$DIR/${tlist%%.html}.t.tmplist"
    local tslist="${tlist%%.t.tmplist}.ts.tmplist"
    if [ "$tlist" = "$DIR/.t.tmplist" ]; then
        echo "... $tlist (tlist) has no name for index $index" >&2
    elif [ ! -e "$tlist" ]; then
        echo "... $tlist (tlist)" >&2
        # Notes:
        #   --ignore-breaks may or may not be needed (or not matter) based
        #   on the formatting for a given production.
        #   --repeat-span may be helpful or nor based on formatting, too.
        # Other possibly useful flags:
        #   --show-same-row-text-before-cell
        #   --show-same-entry-text-before-links
        #   --show-same-entry-text-before-here
        #   --show-same-entry-text-after-here
        #   --show-same-entry-text-after-links
        #   --show-same-row-text-after-cell
        #   --show-cell-line-number
        ./print-table-links.pl --show-bold-or-heading --show-column-number \
                               --show-text-at-col 0 \
                               --show-same-entry-text-before-here \
                               --show-text-at-row 0 \
                               --show-text \
                               --separator '~' --output-by-line --merge-links \
                               --ignore-breaks \
                               --repeat-span \
                               --base "$base_uri" "$index" > "$tlist"
        if [[ -n "$force_https" ]]; then
            echo "... $tslist (tlist+https)" >&2
            sed -e 's,	http\(://\(www.\)\?familyopera.org/\),	https\1,g' \
                < "$tlist" > "$tslist"
        fi
    fi
    if [[ -z "$force_https" ]]; then
        echo "$tlist"
    else
        echo "$tslist"
    fi
}

get_mp3_sections () {
    local tlist="$1"; shift
    local plist="$1"; shift
    if [[ -n "$use_tables" ]]; then
        sed -e '/\.mp3$/I!d;s/	.*//' "$tlist" | uniq
    else
        sed -e '/\.mp3$/I!d;s/	.*//' "$plist" | uniq
    fi
}

uniq_in_order () {
    local seen=()
    while read line; do
        for s in "${seen[@]}"; do
            if [ "x$line" = "x$s" ]; then continue 2; fi
        done
        echo "$line"
        seen+=("$line")
    done
}

get_table_section_field () {
    local tlist="$1"; shift
    local section="$1"; shift
    local field_index="$1"; shift
    local field_or_sep_index="$1"; shift

    local skips=()
    local i
    for ((i=0; i<"$field_index"; ++i)); do
        skips+=(-e 's/^[^	]*	//')
    done
    for ((i=0; i<"$field_or_sep_index"; ++i)); do
        skips+=(-e 's/^[^~	]*[~	]//')
    done

    sed -e '/\.mp3$/I!d;/^'"$section"'/I!d' \
              "${skips[@]}" \
              -e 's/[~	].*//' \
              "$tlist" \
        | uniq_in_order
}

filter_by_field () {
    local field_index="$1"; shift
    local value="$1"; shift
    awk -F '[~	]' -v value="$value" '($'"$field_index"' == value)'
}

remove_field () {
    local field_index="$1"; shift
    sed -e 's/^\(\([^	]*	\)\{'"$field_index"'\}\)[^	]*	/\1/'
}

merge_field_with_next () {
    local field_index="$1"; shift
    local sep="$1"; shift
    sed -e 's@^\(\([^	]*	\)\{'"$field_index"'\}[^	]*\)	@\1'"$sep"'@'
}

process_text_section_columns () {
    local section="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local text_style=replace
    #local text_style=prepend
    local out_tag=out_file
    if [ "$text_style" = prepend ]; then
        out_tag=out_file_prefix
        files_suffix="$files_suffix "
    fi

    local voices_regex=
    for voice in "${voice_parts[@]}"; do
        voices_regex="${voices_regex}${voice,,}\\|"
    done
    voices_regex="${voices_regex%%\\|}"

    sed -e '/\.mp3$/I!d' `# skip non-MP3 links` \
        -e '/^'"$section"'/I!d' `# filter sections (bold-or-heading)` \
        -e 's/^[^	]*	//' `# remove section (bold-or-heading)` \
        `# Remove //, which is the hardcoded separator from less-indented:` \
        -e 's,^\([^	]*\)  *//  *,\1 ,' \
        -e 's,^\([^	]*\)  *//  *,\1 ,' \
        -e 's,^\([^	]*\)  *//  *,\1 ,' \
        -e 's/^\([^	]*\)	[^	]*/\1/' `# keep less-indented, remove previous-line-text` \
        -e 's/^\([^	]*\)	[^	]*/\1/' `# remove line-text` \
        -e '' \
        -e 's/^\([^	]*\)	/\1 /' `# combine line-before-link into track name` \
        -e 's/^\([^	]*\)	/\1 /' `# combine text into track name` \
        -e 's/^\([^	]*\)	[^	]*/\1/' `# remove line-after-link` \
        `# If there's an unclosed parenthesis in the track name, force it closed:` \
        -e 's/^\([^	]*([^)	]*\)	/\1)	/' \
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
        `# voice subpart labeling` \
        -e '/\('"${voices_regex}"'\) *1/Is,\(out_file[_a-z]*:[SATB]\) ,\11 ,' \
        -e '/\('"${voices_regex}"'\) *2/Is,\(out_file[_a-z]*:[SATB]\) ,\12 ,' \
        -e '/KCCC/s,\(out_file[_a-z]*:[SATB]\) ,\1cc ,' \
        `# final fixups` \
        -e 's/\(Scene \)1 \(1[a-z]\)/\1\2/' \
        -e 's,\( *-\)\?  *rev [1-9][0-9]\?/[1-9][0-9]\?/1[78] ([^()	]*),,I' \
        -e ''
}

process_table_section_columns () {
    local section="$1"; shift
    local column_num="$1"; shift
    local column_heading="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local text_style=replace
    #local text_style=prepend
    local out_tag=out_file
    if [ "$text_style" = prepend ]; then
        out_tag=out_file_prefix
        files_suffix="$files_suffix "
    fi

    sed -e '/\.mp3$/I!d' `# skip non-MP3 links` \
        -e '/^'"$section"'/I!d' `# filter sections (bold-or-heading)` \
        -e 's/^[^	]*	//' `# remove section (bold-or-heading)` \
        -e '/^'"$column_num"'	/!d' `# filter column numbers` \
        -e 's/^[^	]*	//' `# remove column number` \
        -e '/^[^	]*	'"$column_heading"'	/!d' `# filter column labels` \
        `# move *specific* bits of pre-link text to track name:` \
        -e 's/^\([^	]*\)	\(heavenly choir\|intro\|coda\|second verse\|third verse\)/\1 \2	/' \
        -e 's/^\([^	]*\)	[^	]*/\1/' `# remove pre-link text` \
        `# move *specific* bits of link text to track name:` \
        -e 's/^\([^	]*\)\(	[^	]*	\)\(heavenly choir\|intro\|coda\|second verse\|third verse\)/\1 \3\2/' \
        -e 's/	/, /' `# merge columns (row/track name + table column name)` \
        -e 's/, 	/	/' `# strip trailing comma+space` \
        -e 's/	/, /' `# merge columns (track,chorus + link text)` \
        -e 's/, 	/	/' `# strip trailing comma+space` \
        -e 's/third verse third verse/third verse/' \
        `# use the scene "#.#" number from filename if available:` \
        -e 's/^\([^	]*	\)\(.*\(Sc\|Practice_\)\([1-9][0-9]*\)[-.]\([0-9][0-9]*\)\)/\4.\5 \1\2/' \
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
        `# final fixups` \
        -e '/Pulverizer/I{;/PulverizerIntro/s/Intro Coda/intro/Ig;}' \
        -e '/Pulverizer/I{;/PulverizerIntro/!s/Intro Coda/coda/Ig;}' \
        -e '/Pinkie Bender/I{;/PinkieWithCuts/!s/ (with cuts)/ (std)/;}' \
        -e '/Drowned at Birth/I{;/HChoir/!s/heavenly choir/coda/;}' \
        -e '/Everyone Has a Story/I{;s/second verse \(third verse\)/\1/;}' \
        -e '/Everyone Has a Story/I{;/StoryEnd/s/second verse/third verse/;}' \
        -e ''
}

extract_demorch () {
    local plist="$1"; shift
    local section="$1"; shift
    local file="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    local out_tag=out_file
    echo "::: $DIR/$file.mp3.tmplist (demo/orch)" >&2
    cat "$plist" \
        | sed -e '/\.mp3$/I!d' \
              -e '/^'"$section"'/I!d' `# filter sections` \
              -e 's/^[^	]*	//' `# remove section (bold-or-heading)` \
              `# Remove //, which is the hardcoded separator from less-indented:` \
              -e 's,^\([^	]*\)  *//  *,\1 ,' \
              -e 's,^\([^	]*\)  *//  *,\1 ,' \
              -e 's,^\([^	]*\)  *//  *,\1 ,' \
              -e 's/^\([^	]*\)	[^	]*/\1/' `# keep less-indented, remove previous-line-text` \
              -e 's/^\([^	]*	\)[^	]*	/\1/' `# remove same line text (line-text)` \
              -e 's/^\([^	]*\)	/\1 /' `# combine same line before link (line-before-link) into track name` \
              -e 's/^\([^	]*\)	/\1 /' `# combine link text (text) into track name` \
              -e 's/^\([^	]*\)	/\1 /' `# combine same line after link (line-after-link) into track name` \
              `# remove some common labeling we don't care about:` \
              -e 's,\( *-\)\?  *rev [1-9][0-9]\?/[1-9][0-9]\?/1[78] ([^()	]*),,I' \
              -e 's, *(\(added  *\|updated  *\)\?[1-9][0-9]\?/[1-9][0-9]\?/1[78]),,I' \
              -e 's, *(updated  *12/30),,I' `# specific update from 2017` \
              -e 's,^\(act  *II*  *scene  *[1-9][0-9]*[a-z]\?\)\(  *-\)\? *,\1 - ,I' `# add - if missing after scene` \
              `# use the scene "#.#" number from filename if available:` \
              `# commented out block\
              -e 's,^act  *II*  *scene  *[1-9][0-9]*[a-z]\?\( -.*	.*_act1_\?sc\)\([1-9][0-9]*[a-z]\?\)\([-_]\),Act I Scene \2\1\2,I' \
              -e 's,^act  *II*  *scene  *[1-9][0-9]*[a-z]\?\( -.*	.*_act2_\?sc\)\([1-9][0-9]*[a-z]\?\)\([-_]\),Act II Scene \2\1\2,I' \
              # end of commented-out block` \
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

process_section_non_table_extras () {
    local section="$1"; shift
    local less_indented="$1"; shift
    local files_prefix="$1"; shift
    local files_infix="$1"; shift
    local files_suffix="$1"; shift

    local out_tag=out_file

    sed -e '/\.mp3$/I!d' \
        -e '/^'"$section"'/I!d' `# filter sections` \
        -e 's/^[^	]*	//' `# remove section (-hb)` \
        -e '/^'"$less_indented"'/I!d' `# filter the less indented line` \
        -e 's/^[^	]*	//' `# remove less indented (-li)` \
        -e 's/^[^	]*	//' `# remove previous line (-plt)` \
        -e 's/^[^	]*	//' `# remove same line (-lt)` \
        `# merge same line before link (-lb), link text (-t), same line after link (-la):` \
        -e 's/^\([^	]*\)	/\1 /' \
        -e 's/^\([^	]*\)	/\1 /' \
        -e 's/^/'"$files_infix"'/' `# add infix before the text but after scene # if any` \
        `# use the scene "#.#" number from filename if available:` \
        -e 's/^\([^	]*	\)\(.*\(Sc\|Practice_\)\([1-9][0-9]*\)[-.]\([1-9][0-9]*\)\)/\4.\5 \1\2/' \
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
        -e ''
}

extract_satb_sections () {
    local tlist="$1"; shift
    local plist="$1"; shift
    local sec_prefix="$1"; shift
    local sec_suffix="$1"; shift
    local list_prefix="$1"; shift
    local list_suffix="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift

    echo "vvv (begin SATB sections)" >&2
    if false; then
        # For debugging & dev: show all column names
        get_table_section_field "$tlist" "$sec_prefix[^	]*$sec_suffix" 3 0 \
            | sed -e '/^Scene/d;/^Song$/d'
    fi

    for voice in "${voice_parts[@]}"; do
        #local short="`echo "$voice" | sed -e 's/^\(.\)[^ ]* \?/\1/'`"
        local short="`echo "$voice" | sed -e 's/[^A-Z]//g'`"
        local short_up="${short^^}"
        local full_voice="$voice"
        # doesn't filter by column heading, but includes it in file name
        local file="${list_prefix}${voice,,}${list_suffix}"
        if true; then
            echo "::: $DIR/$file.mp3.tmplist (SATB sections, no tables)" >&2
            cat "$plist" \
                | process_text_section_columns \
                    "$sec_prefix$full_voice$sec_suffix" \
                    "$files_prefix${short_up} " \
                    "$files_suffix" \
                    > "$DIR"/frag-"$file"-links.mp3.tmplist
            cat "$DIR"/frag-"$file"-links.mp3.tmplist | sed \
                -e '' \
                > "$DIR"/"$file".mp3.tmplist
        else
            echo "::: $DIR/$file.mp3.tmplist (SATB sections/table columns/extras)" >&2
            cat "$tlist" \
                | process_table_section_columns \
                    "$sec_prefix$full_voice$sec_suffix" \
                    '[1-9][0-9]*' \
                    '[^	]*' \
                    "$files_prefix${short_up} " \
                    "$files_suffix" \
                    > "$DIR"/frag-"$file"-table.mp3.tmplist
            cat "$plist" \
                | process_section_non_table_extras \
                    "$sec_prefix$full_voice$sec_suffix" \
                    "[^	]*Summon the clouds" \
                    "$files_prefix${short_up} " \
                    " Rain Dance 2, Summon the clouds, " \
                    "$files_suffix" \
                    > "$DIR"/frag-"$file"-extras.mp3.tmplist
            cat "$DIR"/frag-"$file"-table.mp3.tmplist | sed \
                -e '/NOOP/d' \
                > "$DIR"/"$file".mp3.tmplist
#            cat "$DIR"/frag-"$file"-extras.mp3.tmplist | sed \
#                -e "/Rain Dance 2/!d" \
#                >> "$DIR"/"$file".mp3.tmplist
        fi
    done
    echo "^^^ (end SATB sections)" >&2
}

extract_single_solo () {
    local tlist="$1"; shift
    local column_heading="$1"; shift
    local files_prefix="$1"; shift
    local files_suffix="$1"; shift
    local file="$1"; shift

    echo "::: $DIR/$file.mp3.tmplist (solo sections/table columns)" >&2
    cat "$tlist" \
        | merge_field_with_next 2 ', ' \
        | process_table_section_columns \
              '[^	]*' '[1-9][0-9]*' "$column_heading" \
              "$files_prefix" "$files_suffix" \
              > "$DIR"/"$file".mp3.tmplist

    echo "+++ $DIR/all-solos.mp3.tmplist (partial)" >&2
    cat "$DIR"/"$file".mp3.tmplist >> "$DIR"/all-solos.mp3.tmplist
}

extract_solos () {
    local tlist="$1"; shift

    echo "vvv (begin solos)" >&2
    if false; then
        # For debugging & dev: show all column names
        get_table_section_field "$tlist" "[^	]*" 4 0 \
            | sed -e '/^Scene/d;/^Song$/d'
    fi

#    extract_single_solo "$tlist" "Roli" "Roli " "" "roli-solo"
#    extract_single_solo "$tlist" "Mandisa" "Mandisa " "" "mandisa-solo"
#    extract_single_solo "$tlist" "Leverets" "Leverets " "" "leverets-solo"
#    extract_single_solo "$tlist" "Koni" "Koni " "" "koni-solo"
#
#    extract_single_solo "$tlist" "Tau" "Tau " "" "tau-solo"
#    extract_single_solo "$tlist" "Balosi" "Balosi " "" "balosi-solo"
#    extract_single_solo "$tlist" "Ndanga" "Ndanga " "" "ndanga-solo"
#    extract_single_solo "$tlist" "Johnny panned right Jackie panned left" "J+J " "" "j+j-solo"
#    extract_single_solo "$tlist" "Antoine" "Antoine " "" "antoine-solo"
#
#    extract_single_solo "$tlist" "Bello" "Bello " "" "bello-solo"
#    extract_single_solo "$tlist" "Hobo" "Hobo " "" "hobo-solo"
#    extract_single_solo "$tlist" "Thendo" "Thendo " "" "thendo-solo"
#    extract_single_solo "$tlist" "Kipling" "Kipling " "" "kipling-solo"
#    extract_single_solo "$tlist" "Dikeledi" "Dikeledi " "" "dikeledi-solo"

    echo "^^^ (end solos)" >&2
}

prepare_link_check () {
    local index="$1"; shift
    local base="${index##*/}"; base="$DIR/${base%%.html}"
    echo "~~~ $base.lc*.tmplist" >&2
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
    # note: no 'Chorus MP3s' suffix for Weedpatch
    extract_satb_sections "$(tlist "$INDEX_CHORUS")" "$(plist "$INDEX_CHORUS")" \
                          '' '' \
                          '' '-chorus' \
                          '' ''

    # Note: when supporting solos are in their own separate section, it looks
    # something like this:
#    echo "::: $DIR/all-supporting.mp3.tmplist (supporting solo sections/table columns)" >&2
#    cat "$(tlist "$INDEX_CHORUS")" \
#        | remove_field 3 \
#        | process_table_section_columns \
#              "SUPPORTING" '[1-9][0-9]*' '[^	]*' '' ''\
#              > "$DIR"/all-supporting.mp3.tmplist
#    for s in clement thomasina walter myles edmund \
#             'cabin boy' \
#             tavernkeeper 'reveler 1' 'reveler 2' 'reveler 3' 'reveler 4' \
#             'captain gouda' 'henk' 'schenk' 'denk' \
#             jolye dowland \
#             soldier yeoman ; do
#        f="${s// /-}"
#        echo "~~~ $DIR/$f.mp3.tmplist (supporting)" >&2
#        cat "$DIR"/all-supporting.mp3.tmplist \
#            | grep -i '\<'"$s"'\(,\| *&\)' \
#            | uniq \
#             > "$DIR"/"$f".mp3.tmplist
#    done
fi

if [ -n "$INDEX_SOLO" ]; then
    extract_solos "$(tlist "$INDEX_SOLO")"
fi

if [ -n "$INDEX_DEMO" ]; then
    extract_demorch "$(plist "$INDEX_DEMO")" 'DEMO' 'demo'
fi
if [ -n "$INDEX_ORCH" ]; then
    extract_demorch "$(plist "$INDEX_ORCH")" \
                    'ORCHESTRA.*' 'orchestra'
fi
#if [ -n "$INDEX_SCENE" ]; then
#    extract_demorch "$(plist "$INDEX_SCENE")" \
#                    'soundtrack\|sound track' 'scenes'
#fi


if [ -n "$do_generate_all_voices" -a -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/{soprano,alto,ac,tenor,bass}-*.mp3.tmplist | sed \
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

### generating generic zip files

split_with_sed () {
    local input="$1"; shift
    local result=1
    local outputs=()
    local script output
    while [[ "$#" -gt 0 ]]; do
        script="$1"; shift
        output="$1"; shift
        outputs+=("$output")
        sed -e "$script" < "$input" > "${DIR}/$(basename "${output}").tmp"
        if [[ -s "${DIR}/$(basename "${output}").tmp" ]] && \
               ! diff -q "${input}" "${DIR}/$(basename "${output}").tmp" > /dev/null; then
            result=0
        fi
    done
    if [[ "$result" == 0 ]]; then
        # some output files are different from the input
        # we DO NOT remove the input, we will just take care not to copy it!
        for output in "${outputs[@]}"; do
            mv "${DIR}/$(basename "${output}").tmp" "${output}"
        done
    fi
    return "$result"
}

split_camper_townie () {
    local name_a="$1"; shift
    local name_b="$1"; shift
    split_with_sed "${DIR}/${name_a}${name_b}.mp3.tmplist" \
                   '/townie/Id' "${DIR}/${name_a} camper${name_b}.mp3.tmplist" \
                   '/camper/Id' "${DIR}/${name_a} townie${name_b}.mp3.tmplist"
}
split_1_2 () {
    local name_a="$1"; shift
    local name_b="$1"; shift
    split_with_sed "${DIR}/${name_a}${name_b}.mp3.tmplist" \
                   '/:[SATB]2 /d' "${DIR}/${name_a} 1${name_b}.mp3.tmplist" \
                   '/:[SATB]1 /d' "${DIR}/${name_a} 2${name_b}.mp3.tmplist"
}
cp_for_zip () {
    local name="$1"; shift
    if [ -n "$do_generate_zip" ]; then
        cp "${DIR}/${name}.mp3.tmplist" "${name}.mp3.urllist"
    fi
}

inputs=()
for i in "$INDEX_CHORUS" "$INDEX_SOLO"; do
    if [ -n "$i" ]; then
        sections=()
        while read -r section; do
            sections+=("$section")
        done < <(get_mp3_sections "$(tlist "$i")" "$(plist "$i")")
        for section in "${sections[@]}"; do
            base="${section,,}"; base="${base// /-}"
            base_out="$base"
            if [[ "${base}" == "ac" ]]; then
                base_out="AC"
            fi
            input="${DIR}/${base}-chorus.mp3.tmplist"
            if [[ -e "${input}" ]]; then
                inputs+=("${input}")
                cat "${input}" | sed \
                    -e '/KCCC/d' \
                    > "${DIR}/${base_out}.mp3.tmplist"
                if split_camper_townie "${base_out}" ""; then
                    if split_1_2 "${base_out}" " camper"; then
                        cp_for_zip "${base_out} 1 camper"
                        cp_for_zip "${base_out} 2 camper"
                    else
                        cp_for_zip "${base_out} camper"
                    fi
                    if split_1_2 "${base_out}" " townie"; then
                        cp_for_zip "${base_out} 1 townie"
                        cp_for_zip "${base_out} 2 townie"
                    else
                        cp_for_zip "${base_out} townie"
                    fi
                else
                    if split_1_2 "${base_out}" ""; then
                        cp_for_zip "${base_out} 1"
                        cp_for_zip "${base_out} 2"
                    else
                        cp_for_zip "${base_out}"
                    fi
                fi
            fi
        done
    fi
done
if [[ "${#inputs[@]}" -gt 0 ]]; then
    cat "${inputs[@]}" | sed \
        -e '/KCCC/!d' \
        -e 's/:Scc /:Citizens Committee soprano /' \
        -e 's/:Acc /:Citizens Committee alto /' \
        -e 's/:Tcc /:Citizens Committee tenor /' \
        -e 's/:Bcc /:Citizens Committee bass /' \
        > "${DIR}/Kern County Citizens Committee.mp3.tmplist"
    if [[ -s "${DIR}/Kern County Citizens Committee.mp3.tmplist" ]]; then
        cp_for_zip "Kern County Citizens Committee"
    fi
fi

#    if [ -n "$INDEX_CHORUS" ]; then
#        section="SUPPORTING"
#        get_table_section_field "$(tlist "$INDEX_CHORUS")" "$section" 2 1 \
#        | while read -r who; do
#            base="$who"
#            cat "$(tlist "$INDEX_CHORUS")" \
#                | remove_field 3 \
#                | filter_by_field 4 "$who" \
#                | process_table_section_columns "$section" '[^	]*' \
#                                                '[^	]*' '' '' \
#                | sed -e 's/	.*$//' \
#                      > "$base".mp3zip.urllist
#            # some links may be repeated in the list, but that's OK
#        done
#    fi
#fi

### no Katarina ;(

### Luka (Alto)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    snip_allow='.'  # this will always match
    #for snip_deny in 'THIS_WILL_NOT_MATCH'; do
    #    cat "$DIR"/alto-chorus.mp3.tmplist | sed \
    #        -n \
    #        -e '/Security, Security/p' \
    #        -e '/Case Number One, Audience/p' \
    #        -e '/Barbara [124], Audience/p' \
    #        -e '/Pulverizer, Audience, coda/p' \
    #        -e '/Itty Bitty Child, Audience/p' \
    #        -e '/Johnny.*Britney, Audience/p' \
    #        -e '/Agnes Testifies, Audience/p' \
    #        -e '/Everyone Has a Story.*, Audience/p' \
    #        -e '/Gingerbread House 3, Audience/p' \
    #    | sed \
    #        -e '/'"$snip_allow"'/,$!d' \
    #        -e '/'"$snip_deny"'/,$d' \
    #        >> Luka.mp3.urllist
    #    snip_allow="$snip_deny"
    #done
    cat "$DIR"/alto.mp3.tmplist | sed \
        -e '' \
        > Luka.mp3.urllist
fi

### bert (Tenor)
# MP3s
if [ -n "$INDEX_CHORUS" ]; then
    cat "$DIR"/tenor.mp3.tmplist | sed \
        -e 's/out_file:TB /out_file:T /' \
        > Abbe+bert.mp3.urllist
fi

### Abbe (Alto)
# MP3s
#if [ -n "$INDEX_CHORUS" ]; then
#    cat "$DIR"/tenor.mp3.tmplist | sed \
#        -e '' \
#        > Abbe.mp3.urllist
#fi

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
    echo "@@@ demo" >&2
    cat tmplists/demo.mp3.tmplist \
        | sed -e '/Rehearsal/Id' \
              -e '/Pink\(ie\|y\).*Demo.*\.mp3.*with cuts/I{;/Pink\(ie\|y\).*WithCuts.*\.mp3/I!{;s/ *(with cuts)//;};}' \
              > demo.mp3.urllist
    echo "@@@ rehearsal" >&2
    cat tmplists/demo.mp3.tmplist \
        | sed -e '/Rehearsal/I!d' \
              > rehearsal.mp3.urllist
fi

### orchestra-only MP3s
if [ -n "$do_generate_orchestra" -a -e tmplists/orchestra.mp3.tmplist ]; then
    echo "@@@ orchestra" >&2
    cat tmplists/orchestra.mp3.tmplist \
        > orchestra.mp3.urllist
fi
#if [ -n "$do_generate_scenes" -a -e tmplists/scenes.mp3.tmplist ]; then
#    echo "@@@ scenes (Red)" >&2
#    cat tmplists/scenes.mp3.tmplist \
#        | sed -e '/:I\.3/!{;/Gold/d;}' \
#        > scenes-red.mp3.urllist
#fi

### score PDFs

if [ -n "$INDEX_PDF" ]; then
    echo "@@@ score" >&2

    ./plinks.pl --base "$base_uri" "$INDEX_PDF" \
        | sed  -e '/\.pdf$/I!d' \
               -e '/^[^	]*score/I!d;/LibrettoBook/d;/OPERA-PARTY/d' \
               -e 's/^[^	]*	//' \
               -e 's/^[^	]*	//' > score.pdf.urllist
fi
