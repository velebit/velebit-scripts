#!/bin/bash

apt_install='apt install --no-upgrade'
#apt_install='apt install --no-upgrade --install-suggests'
#apt_install="`dirname "$0"`/check-package-recommends"

packages=()

is_selected () {
    local args="$1"
    args="${args// /,},"
    local first rest
    while [ -n "$args" ]; do
        rest="${args#*[+,]}"
        first="${args%$rest}"
        case "$first" in
            always,|yes,|!no,|!,|!!yes,|!!!no,|!!!,)
                return 0 ;;             # true condition -> selected
            no,|,|!yes,|!!no,|!!,|!!!yes,)
                args="$rest" ;;         # false condition -> keep going
            always+|yes+|!no+|!+|!!yes+|!!!no+|!!!+)
                args="$rest" ;;         # true `+` element -> look at more
            no+|+|!yes+|!!no+|!!+|!!!yes+)
                args="${args#*,}" ;;    # false `+` element -> discard to `,`
            *)
                echo "Warning: invalid selection value '$first'" >&2
                args="${args#*,}" ;;    # discard to `,` and keep going
        esac
    done
    return 1   # false
}

add_if () {
    local cond="$1"; shift
    local i
    if is_selected "$cond"; then
        if [ "$#" -eq 0 ]; then
            echo "Warning: no packages to add" >&2
        fi
        for i in "$@"; do
            packages+=("$i")
        done
    fi
}

is_primary_os=yes
is_remote=yes
is_server=yes
is_media=yes
is_bert_desktops=yes
is_multiuser=

drv_nvidia=
drv_nvidia_opti=

## OS, desktop environment, system maintainenace and diagnostics
add_if always               bash-completion
add_if always               emacs
add_if always               xclip
add_if always               sysstat
add_if "$is_primary_os"     firmware-linux   # in non-free!
add_if "$is_primary_os"     smartmontools nvme-cli
add_if "$is_primary_os"     discover hdparm
add_if "$is_primary_os"     mdadm
add_if "$is_primary_os"     cryptsetup-bin cryptsetup-run keyutils
add_if always               perl perl-doc
add_if always               python3 ipython3 python3-pip
add_if always               python3-tk
add_if always               graphviz
add_if always               iputils-ping traceroute
add_if always               telnet netcat-traditional
add_if always               tcpdump dhcpdump wireshark tshark nmap
add_if always               lsof iotop
add_if always               task-desktop
add_if "$is_remote"         task-ssh-server
add_if "$is_server"         task-print-server foomatic-db-engine
add_if "$is_server"         printer-driver-all openprinting-ppds
add_if "$is_primary_os"     cups printer-driver-cups-pdf
add_if always               task-cinnamon-desktop
add_if "$is_bert_desktops"  task-xfce-desktop
add_if "$is_multiuser"      task-mate-desktop
add_if "$is_multiuser"      task-lxqt-desktop
add_if "$is_primary_os"     gconf-editor
add_if "$is_multiuser"      libnotify-bin

add_if "$is_server"         restic
add_if "$is_primary_os"     rclone

add_if "$is_server"         isc-dhcp-server
add_if "$is_server"         samba
add_if always               rsync
add_if always               jigdo-file
add_if always               screen
add_if always               flatpak

add_if "$is_server"         virt-manager
add_if "$is_server"         qemu-system-x86
add_if "$is_server"         qemu-system-arm
add_if "$is_server"         qemu-block-extra vde2
add_if always               fatresize

add_if always               gnome-terminal
# mate-terminal

add_if "$drv_nvidia"                    nvidia-driver
add_if "$drv_nvidia_opti+$drv_nvidia"   bumblebee-nvidia primus
add_if "$drv_nvidia_opti+!$drv_nvidia"  bumblebee primus
add_if "$drv_nvidia_opti+$is_multiuser" mate-optimus

# nvidia-detect <-- TEMPORARY
# xfce4-mixer
# no need for crypt disk setup at boot (cryptsetup, cryptsetup-initramfs)

## development and the like
add_if always               gcc g++
add_if always               strace
add_if always               libhtml-element-extended-perl \
                                libhtml-tableextract-perl
add_if always               libtext-unidecode-perl libtext-unaccent-perl
add_if "$is_primary_os"     sonic-pi

### file versioning, comparison and whatnot
add_if always               git git-svn subversion
add_if always               meld

### local network and maintenance tools
add_if always               sshfs

### Internet tools
add_if always               chromium
add_if always               whois dnsutils
# youtube-dl is installed from upstream because Debian version is very old

### media tools
add_if always               atomicparsley libmp3-tag-perl
add_if always               python-rgain
add_if always               picard
add_if always               audacity
add_if always               musescore
add_if always               jhead libimage-exiftool-perl exiv2
add_if always               paprefs
add_if always               sox libsox-fmt-all
add_if always               darktable
add_if always               blender
add_if "$is_media"          vlc libavcodec-extra
add_if "$is_media"          ffmpeg
#add_if "$is_media"          kodi

# Installed via Python because Debian version sometimes can't load data:
#   eyed3

### medical imaging tools
# (set up via Flatpak)
#add_if "$is_server"         invesalius

#### video editing
# (set up via Flatpak)
# flowblade
# openshot
# olive-editor
# pitivi? (installable)
# lives/LiVES? (installable)
# shotcut? (flatpak/snap)
# avidemux? (flatpak)

#### DVD creation
add_if always               devede
# bombono? (not installable)

#### CD/DVD burninating
add_if always               genisoimage xorriso
add_if always               wodim cdrskin cdrdao cue2toc
add_if always               k3b brasero xfburn
add_if always               libcdio-utils
add_if always               cdck

### PDF tools
add_if always               pdftk-java
add_if "$is_bert_desktops"  texlive-extra-utils  # pdfjam, pdfbook and friends
add_if always               xournal

### other document tools
add_if "$is_bert_desktops"  pandoc

#### 32-bit compat (for e.g. Brother binaries)
#if is_selected "$is_server"; then
#    dpkg --add-architecture i386
#    # ...redo "apt update" if necessary...
#fi
add_if "$is_server"         libc6:i386

# Minecraft and MultiMC deps
add_if "$is_multiuser"      libcurl4
add_if "$is_multiuser"      qt5-default
# extracted locally: jdk-8u###-ojdkbuild-linux-x64
add_if "$is_multiuser"      acct  # needed to track L
add_if "$is_multiuser"      at  # needed to manage L

### PROPRIETARY, installed locally:
# Brother: hll8350cdwlpr hll8350cdwcupswrapper

$apt_install "${packages[@]}"
