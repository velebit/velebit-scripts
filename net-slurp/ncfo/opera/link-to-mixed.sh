#!/bin/bash

dir=mixed
top_prefix='../../../'

UPDATE_EXISTING=
VERBOSE_EXISTING_SKIPPED=
VERBOSE_EXISTING_UPDATED=

declare -A dir_created
declare -A dir_skipped
declare -A dir_updated

prep_link () {
    local link_dir="$1"; shift
    local mixed="$1"; shift

    if [ -d "$link_dir" ]; then
        if [ -n "${dir_created[$link_dir]}" ]; then
            :  # directory created earlier in this script execution, fill it
        elif [ -z "$UPDATE_EXISTING" ]; then
            if [ -n "$VERBOSE_EXISTING_SKIPPED" \
                    -a -z "${dir_skipped[$link_dir]}" ]; then
                echo -e "\e[32m$link_dir: already exists, skipped.\e[0m"
            fi
            dir_skipped[$link_dir]=yes
            return
        else
            if [ -n "$VERBOSE_EXISTING_UPDATED" \
                    -a -z "${dir_updated[$link_dir]}" ]; then
                echo -e "\e[32m$link_dir: already exists, creating links.\e[0m"
            fi
            dir_updated[$link_dir]=yes
        fi
    elif mkdir -p "$link_dir"; then
        dir_created[$link_dir]=yes
        echo -e "\e[35m$link_dir: created.\e[0m"
    else
        echo -e "\e[31m$link_dir: could not create.\e[0m"
        exit 5
    fi

    local dest="$link_dir/$(basename "$mixed")"
    local re_
    if [ -L "$dest" ]; then re_="re-"; else re_=""; fi
    if ln -sf "$mixed" "$link_dir/"; then
        echo -e "\e[35m$dest: link ${re_}created.\e[0m"
    else
        echo -e "\e[31m$dest: could not ${re_}create link.\e[0m"
        exit 6
    fi
}

log_final_stats () {
    if [ -z "$VERBOSE_EXISTING_SKIPPED" -a "${#dir_skipped[@]}" -gt 0 ]; then
        echo -e "\e[32m${#dir_skipped[@]} existing directories were" \
             "skipped.\e[0m"
    fi
    # echo -e "\e[35m${#dir_created[@]} directories were created.\e[0m"
    existing_skipped=0
}

Usage () {
    if [ "$#" -gt 0 ]; then
        local i
        for i in "$@"; do
            echo "$i" >&2
        done
        echo '' >&2
    fi
    cat <<EOF >&2
Usage: $(basename "$0") [-a][-v][-h] [FILES...]
Options:
  --all     (-a)  Update the existing "extras" directories.  The default is to
                  only populate directories if they didn't previously exist.
  --verbose (-v)  Add more verbose messages.
  --help    (-h)  Show this message.
Other arguments:
  FILES...        Optionally only process specified files. The default is to
                  process all MP3 files in the "$dir" directory.
EOF
}

files=()
for i in "$@"; do
    case "$i" in
        -a|--all)
            UPDATE_EXISTING=yes
            ;;
        -v|--verbose)
            VERBOSE_EXISTING_SKIPPED=yes
            VERBOSE_EXISTING_UPDATED=yes
            ;;
        -h|-\?|--help)
            Usage
            exit 0
            ;;
        -*)
            Usage "Unknown command line option '$i'"
            exit 1
            ;;
        *)
            files+=("$i")
            ;;
    esac
done

if [ "${#files[@]}" -eq 0 ]; then
    files=("$dir"/*.mp3)
fi

for mixed in "$dir"/*.mp3; do
    base="$(basename "$mixed" .mp3)"
    track="${base##?mix }"
    track_num="${track%% *}"
    track_num_quoted="${track_num//./\\.}"

    case "$mixed" in
        "$dir"/Smix\ *)
            for who in Katarina; do
                prep_link "mp3-extras/$who/after. $track_num_quoted " \
                          "$top_prefix$mixed"
            done
            ;;
        "$dir"/Amix\ *)
            for who in Luka; do
                prep_link "mp3-extras/$who/after. $track_num_quoted " \
                          "$top_prefix$mixed"
            done
            ;;
        "$dir"/Tmix\ *)
            for who in Abbe bert; do
                prep_link "mp3-extras/$who/after. $track_num_quoted " \
                          "$top_prefix$mixed"
            done
            ;;
        *)
            echo -e "\e[31m$base: Unknown file name structure, skipped.\e[0m"
            ;;
    esac
done
log_final_stats
