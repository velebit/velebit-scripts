#!/bin/bash

cd "`dirname "$0"`" || exit 1
if [ ! -e "`basename "$0"`" ]; then exit 1; fi

DEST="/media/bert/CAR MUSIC"
if [ -d "$DEST/lo-fi" ]; then DEST="$DEST/lo-fi"; fi
if [ ! -d "$DEST" ]; then exit 2; fi

include=(
    "."
)

ignore=(
    # Not sure why absolute paths don't get things ignored:
#    "./Lofi Girl"
#    "./projects"
    "Lofi Girl"
    "projects"
)

exclude_patterns=( '*.sh' '*~' )


# Check if a directory is in the list, or a parent of any in the list.
is_match_or_parent_of () {
    local dir="$1"; shift
    for i in "$@"; do
        case "$i" in
            "$dir"|"$dir"/*)  return 0 ;;  # true
        esac
    done
    return 1  # false
}

# Remove files and directories not in dir list (and not parent dirs)
remove_unlisted () {
    local prunes_o=()
    for i in "$@"; do
        prunes_o+=(-path "$i" -prune -o)
    done
    (cd "$DEST" && find . "${prunes_o[@]}" -print0) |
        while read -r -d '' entry; do
            if is_match_or_parent_of "$entry" "$@"; then
                :  # is included (or parent), keep
            elif [ ! -e "$DEST/$entry" ]; then
                :  # already removed, ignore
            elif [ -d "$DEST/$entry" ]; then
                echo "Removing non-included dir:  $entry"
                rm -rf "$DEST/$entry"
            else
                echo "Removing non-included file: $entry"
                rm -f "$DEST/$entry"
            fi
        done
}

# Remove files and directories matching pattern list
remove_matching () {
    local names=(-false)
    for i in "$@"; do
        names+=(-o -name "$i")
    done
    (cd "$DEST" && find . \( "${names[@]}" \) -print0) |
        while read -r -d '' entry; do
            if [ ! -e "$DEST/$entry" ]; then
                :  # already removed, ignore
            elif [ -d "$DEST/$entry" ]; then
                echo "Removing excluded dir:    $entry"
                rm -rf "$DEST/$entry"
            else
                echo "Removing excluded file:   $entry"
                rm -f "$DEST/$entry"
            fi
        done
}

#remove_unlisted "${include[@]}" "${ignore[@]}"
#remove_matching "${exclude_patterns[@]}"

rsync --info=progress2,flist2,stats2,skip,symsafe --human-readable \
    "${ignore[@]/#/--exclude=}" \
    "${exclude_patterns[@]/#/--exclude=}" \
    --recursive --times --delete --delete-delay --modify-window=2 --fuzzy \
    --relative "${include[@]}" "$DEST/"
# Hint: add -n -v to debug what would happen


remove_unlisted "${include[@]}" "${ignore[@]}"
remove_matching "${exclude_patterns[@]}"
