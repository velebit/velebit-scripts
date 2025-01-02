#!/sourceable/code/for/bash

find_backup_partition () {
    local partlabel="$1"; shift
    local seen=()
    local d
    # More names can be added here, but should be mutually exclusive
    for d in /dev/disk/by-partlabel/"$partlabel"; do
        if [ -b "$d" ]; then seen+=( "$d" ); fi
    done
    if [ "${#seen[@]}" -eq 0 ]; then
        echo "No matching partitions found!" >&2
    elif [ "${#seen[@]}" -ge 2 ]; then
        echo "Multiple matching partitions found!" >&2
    elif [ ! -b "${seen[0]}" ]; then
        echo "Internal error: ${seen[0]} is not a block device!" >&2
    else
        echo "${seen[0]}"
    fi
}

mountable_partition () {
    local partdev="$1"; shift
    local cleartext="$(udisksctl info -b "$partdev" \
                       | awk '($1=="CleartextDevice:"){print $2}')"
    case "$cleartext" in
        "'/'")
            echo 'locked' ;;
        "")
            # Partition is not encrypted
            echo "$partdev" ;;
        "'/org/freedesktop/UDisks2/block_devices/"*)
            local object="${cleartext##\'/org/freedesktop/UDisks2/}"
            object="${object%%\'}"
            local mapped="$(udisksctl info -p "$object" \
                            | awk '($1=="PreferredDevice:"){print $2}')"
            case "$mapped" in
                /dev/mapper/*)
                    echo "$mapped" ;;
                "")
                    echo "No PreferredDevice found for object $object." >&2
                    ;;
                *)
                    echo "Unexpected PreferredDevice for object $object:" \
                         "$mapped" >&2
                    ;;
            esac ;;
        *)
            echo "Unexpected CleartextDevice for partition $partdev:" \
                 "$cleartext" >&2
            ;;
    esac
}

mounted_path () {
    local mountdev="$1"; shift
    udisksctl info -b "$mountdev" \
        | awk '($1=="MountPoints:"){if($2==""){print "none"}else{print $2}}'
}

unlock_partition () {
    local partdev="$1"; shift
    if udisksctl unlock --key-file=/dev/null --no-user-interaction \
                 -b "$partdev"; then
        return 0
    else
        echo "Failed to unlock $partdev." >&2
        return 1
    fi
}

lock_partition () {
    local partdev="$1"; shift
    if udisksctl lock --no-user-interaction \
                 -b "$partdev"; then
        return 0
    else
        echo "Failed to lock $partdev." >&2
        return 1
    fi
}

eject_partition () {
    local partdev="$1"; shift
    if udisksctl power-off --no-user-interaction \
                 -b "$partdev"; then
        echo "Powered off $partdev!" >&2
        return 0
    else
        echo "Failed to power off $partdev." >&2
        return 1
    fi
}

mount_device () {
    local mountdev="$1"; shift
    if udisksctl mount --no-user-interaction \
                 -b "$mountdev"; then
        return 0
    else
        echo "Failed to mount $mountdev." >&2
        return 1
    fi
}

umount_device () {
    local mountdev="$1"; shift
    if udisksctl unmount --no-user-interaction \
                 -b "$mountdev"; then
        return 0
    else
        echo "Failed to unmount $mountdev." >&2
        return 1
    fi
}

do_mount () {
    local backup_name="$1"; shift
    local backup_part="$(find_backup_partition "$backup_name")"
    [ -n "$backup_part" ] || return 1
    local backup_dev="$(mountable_partition "$backup_part")"
    if [ "($backup_dev)" = "(locked)" ]; then
        if ! unlock_partition "$backup_part"; then
            return 2
        fi
        backup_dev="$(mountable_partition "$backup_part")"
        if [ "($backup_dev)" = "(locked)" ]; then
            return 3
        fi
    fi
    case "$backup_dev" in
        "")
            return 4 ;;
        /dev/*) ;;
        *)
            echo "Internal error: unexpected device '$backup_dev'!" >&2
            return 5 ;;
    esac
    local path="$(mounted_path "$backup_dev")"
    case "$path" in
        "")
            echo "Internal error: non-mountable device '$backup_dev'!" >&2
            return 6 ;;
        none)
            if ! mount_device "$backup_dev"; then
                return 7;
            fi
            ;;
        *)
            echo "Device $backup_dev is already mounted at $path." >&2
            ;;
    esac
    return 0
}

do_umount () {
    local backup_name="$1"; shift
    local should_eject="$1"; shift
    local backup_part="$(find_backup_partition "$backup_name")"
    [ -n "$backup_part" ] || return 1
    local backup_dev="$(mountable_partition "$backup_part")"
    if [ "($backup_dev)" = "(locked)" ]; then
        echo "Partition $backup_part is already locked." >&2
    else
        local path="$(mounted_path "$backup_dev")"
        case "$path" in
            none|"")
                # not mounted, don't bother with a message
                ;;
            *)
                if ! umount_device "$backup_dev"; then
                    return 2
                fi
                ;;
        esac
        if [ "($backup_dev)" = "($backup_part)" ]; then
            echo "Partition $backup_part does not need to be locked." >&2
        elif ! lock_partition "$backup_part"; then
            return 3
        fi
    fi
    if [ -n "$should_eject" ]; then
        if ! eject_partition "$backup_part"; then
            return 4
        fi
    fi
    return 0
}
