#!/sourceable/code/for/bash

##### mounting local partitions #####

find_partition () {
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
    local part_name="$1"; shift
    local part="$(find_partition "$part_name")"
    [ -n "$part" ] || return 1
    local dev="$(mountable_partition "$part")"
    if [ "($dev)" = "(locked)" ]; then
        if ! unlock_partition "$part"; then
            return 2
        fi
        dev="$(mountable_partition "$part")"
        if [ "($dev)" = "(locked)" ]; then
            return 3
        fi
    fi
    case "$dev" in
        "")
            return 4 ;;
        /dev/*) ;;
        *)
            echo "Internal error: unexpected device '$dev'!" >&2
            return 5 ;;
    esac
    local path="$(mounted_path "$dev")"
    case "$path" in
        "")
            echo "Internal error: non-mountable device '$dev'!" >&2
            return 6 ;;
        none)
            if ! mount_device "$dev"; then
                return 7;
            fi
            ;;
        *)
            echo "Device $dev is already mounted at $path." >&2
            ;;
    esac
    return 0
}

do_umount () {
    local part_name="$1"; shift
    local should_eject="$1"; shift
    local part="$(find_partition "$part_name")"
    [ -n "$part" ] || return 1
    local dev="$(mountable_partition "$part")"
    if [ "($dev)" = "(locked)" ]; then
        echo "Partition $part is already locked." >&2
    else
        local path="$(mounted_path "$dev")"
        case "$path" in
            none|"")
                # not mounted, don't bother with a message
                ;;
            *)
                if ! umount_device "$dev"; then
                    return 2
                fi
                ;;
        esac
        if [ "($dev)" = "($part)" ]; then
            echo "Partition $part does not need to be locked." >&2
        elif ! lock_partition "$part"; then
            return 3
        fi
    fi
    if [ -n "$should_eject" ]; then
        if ! eject_partition "$part"; then
            return 4
        fi
    fi
    return 0
}

##### mounting remote filesystems #####

is_local_address () {
    local host_addr="$1"; shift
    if [ -n "$(ip addr show to "$host_addr/32")" ]; then
	return 0  # address matches a local interface
    else
	return 1  # address is remote
    fi
}

create_mountpoint () {
    local dir="$1"; shift
    local parent="$1"; shift
    if [[ ! -d "$dir" ]]; then
	if [[ -n "$parent" ]] && [[ ! -d "$parent" ]]; then
            echo "Warning: $parent does not exist." >&2
	fi
	if ! mkdir -p "$dir"; then
            echo "Error: could not create $dir!" >&2
	    return 1
	fi
    fi
    return 0
}

remove_mountpoint () {
    local dir="$1"; shift
    if ! rmdir "$dir"; then
        echo "Warning: could not remove $dir!" >&2
	return 1
    fi
    return 0
}

construct_remote_path () {
    host_name="$1"; shift
    share="$1"; shift
    case "$host_name:$share" in
	aunt-louisa:*)  echo "/common/$share/export" ;;
    esac
}

do_mount_smb () {
    local host_name="$1"; shift
    local host_addr="$1"; shift
    local share="$1"; shift

    local user="$(id -un)"
    #local type=cifs
    local type=smb3
    local parent=/media/"$user"/"$type"
    local dir="$parent"/"$host_name"/"$share"

    if is_local_address "$host_addr"; then
	echo "Error: requested mounting on the server." >&2
	return 1
    fi
    if ! create_mountpoint "$dir" "$parent"; then
	return 1  # message already shown
    fi

    sudo mount -t "$type" -o username="$user",rw \
	 //"$host_addr"/"$share" "$dir"
}


do_umount_smb () {
    local host_name="$1"; shift
    local host_addr="$1"; shift
    local share="$1"; shift

    local user="$(id -un)"
    #local type=cifs
    local type=smb3
    local parent=/media/"$user"/"$type"
    local dir="$parent"/"$host_name"/"$share"

    if [[ ! -d "$dir" ]]; then
	echo "Warning: $dir does not exist, skipped." >&2
	return 0
    fi
    if ! sudo umount "$dir"; then
	echo "Warning: could not unmount $dir." >&2
	return 1
    fi
    if ! remove_mountpoint "$dir"; then
	return 1  # message already shown
    fi
    return 0
}


do_mount_sshfs () {
    local host_name="$1"; shift
    local host_addr="$1"; shift
    local share="$1"; shift
    local rpath="$1"; shift  # optional

    if [[ -z "$rpath" ]]; then
	rpath="$(construct_remote_path "$host_name" "$share")"
	if [[ -z "$rpath" ]]; then return 2; fi
    fi

    local user="$(id -un)"
    local type=ssh
    local parent=/media/"$user"/"$type"
    local dir="$parent"/"$host_name"/"$share"

    if is_local_address "$host_addr"; then
	echo "Error: requested mounting on the server." >&2
	return 1
    fi
    if ! create_mountpoint "$dir" "$parent"; then
	return 1  # message already shown
    fi

    # assume ssh-agent may be holding credentials for Git
    local ssh_options=( -o PubkeyAuthentication=no
			-o PasswordAuthentication=yes )
    sshfs "$user"@"$host_addr":"$rpath" "$dir" "${ssh_options[@]}"
}


do_umount_sshfs () {
    local host_name="$1"; shift
    local host_addr="$1"; shift
    local share="$1"; shift

    local user="$(id -un)"
    local type=ssh
    local parent=/media/"$user"/"$type"
    local dir="$parent"/"$host_name"/"$share"

    # umount_cmd=( fusermount3 -u "$dir" )   # Linux only
    umount_cmd=( umount "$dir" )             # recent Linux, OS X, *BSD...

    if [[ ! -d "$dir" ]]; then
	echo "Warning: $dir does not exist, skipped." >&2
	return 0
    fi
    if ! "${umount_cmd[@]}"; then
	echo "Warning: could not unmount $dir." >&2
	return 1
    fi
    if ! remove_mountpoint "$dir"; then
	return 1  # message already shown
    fi
    return 0
}
