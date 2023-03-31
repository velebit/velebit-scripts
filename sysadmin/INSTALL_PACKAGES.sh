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

file="$(hostname | sed -e 's,\..*,,')/host-settings.sh"
if [ -r "$(dirname "$0")/../$file" ]; then
    source "$(dirname "$0")/../$file"
elif [ -r "$(dirname "$0")/$file" ]; then
    source "$(dirname "$0")/$file"
elif [ -r "../$file" ]; then
    source "../$file"
elif [ -r "./$file" ]; then
    source "./$file"
else
    echo "Error: $file not found!" >&2
    exit 1
fi

#XXX!!!XXX
#firmware-iwlwifi

## OS, desktop environment, system maintainenace and diagnostics
add_if "!$is_vm"            efibootmgr
add_if always               bash-completion
add_if "!$is_headless"      emacs
add_if "$is_headless"       emacs-nox
add_if "!$is_headless"      xclip
add_if always               sysstat
add_if "$is_primary_os"     firmware-linux   # in non-free!
add_if "$is_primary_os"     smartmontools nvme-cli
add_if "$is_primary_os"     discover hdparm
add_if "$is_primary_os"     mdadm
add_if "$is_primary_os"     f3    # flash memory capacity
add_if "$is_primary_os"     fio iozone3  # flash memory (etc) performance
add_if "$is_primary_os"     cryptsetup-bin cryptsetup-run keyutils
add_if "$is_primary_os"     kpartx
add_if "$is_primary_os"     archivemount
add_if "$is_primary_os"     squashfs-tools
add_if always               perl perl-doc
add_if always               python3 ipython3 python3-pip
add_if "!$is_headless"      python3-tk
#add_if "!$is_headless"      python3-numpy python3-scipy python3-matplotlib
#add_if "!$is_headless"      python3-sympy
##add_if "!$is_headless"      python3-imageio python3-eyed3
add_if always               ruby-dev
add_if "!$is_headless"      graphviz
add_if always               iputils-ping traceroute
add_if always               telnet ncat
add_if always               wget curl
add_if always               tcpdump dhcpdump tshark nmap
add_if "!$is_headless"      wireshark
add_if always               lsof iotop time
add_if always               bsdextrautils
add_if "!$is_headless"      task-desktop
add_if "$is_remote"         task-ssh-server
##add_if "$is_server"         task-print-server # removed in bullseye
add_if "$is_server"         cups cups-client cups-bsd
add_if "$is_server"         foomatic-db-engine
add_if "$is_server"         printer-driver-all openprinting-ppds
add_if "$is_primary_os"     cups printer-driver-cups-pdf
add_if "$is_primary_os"     sane sane-utils xsane
add_if "!$is_headless"      task-cinnamon-desktop
add_if "$is_bert_desktop"   task-xfce-desktop
add_if "$is_multiuser"      task-mate-desktop
add_if "$is_multiuser"      task-lxqt-desktop
##XXX TODO add_if "!$is_headless"      xfce4-session # xflock4 -> ?
##add_if "$is_primary_os"     gconf-editor # removed in bullseye
add_if "$is_multiuser"      libnotify-bin

add_if "$is_server"         restic
add_if "$is_primary_os"     rclone

add_if "$is_server"         isc-dhcp-server
add_if "$is_server"         samba samba-vfs-modules
add_if always               rsync
add_if always               jigdo-file
add_if always               screen
add_if "!$is_vm"            flatpak

add_if "$is_server"         virt-manager
add_if "$is_server"         qemu-system-x86
add_if "$is_server"         qemu-system-arm
add_if "$is_server"         qemu-block-extra vde2
add_if "!$is_vm"            fatresize

add_if "!$is_headless"      gnome-terminal
#add_if "!$is_headless"      mate-terminal
#add_if "$is_server"         inadyn

add_if "$is_mc_srv"         default-jre-headless  # currently OpenJDK 11
add_if "$is_mc_srv"         default-jdk-headless  # currently OpenJDK 11
# Note: Java 16 is also installed, from AdoptOpenJDK
##add_if "$is_mc_srv"         mono-core mono-winforms  # for NBTExplorer, pre-bullseye
add_if "$is_mc_srv"         mono-complete  # for NBTExplorer

add_if "$drv_nvidia"                    nvidia-driver
add_if "$drv_nvidia_opti+$drv_nvidia"   bumblebee-nvidia primus
add_if "$drv_nvidia_opti+!$drv_nvidia"  bumblebee primus
add_if "$drv_nvidia_opti+$is_multiuser" mate-optimus

add_if "$drv_bluetooth"     bluetooth
add_if "$drv_bluetooth"     blueman
#add_if "$drv_bluetooth"                 pavucontrol
#add_if "$drv_bluetooth+$is_multiuser"   pavucontrol-qt

# nvidia-detect <-- TEMPORARY
# xfce4-mixer
# no need for crypt disk setup at boot (cryptsetup, cryptsetup-initramfs)

## development and the like
add_if "!$is_vm"            gcc g++
add_if always               strace
add_if always               libhtml-element-extended-perl \
                            libhtml-tableextract-perl
add_if always               libtext-unidecode-perl libtext-unaccent-perl
add_if "$is_primary_os"     sonic-pi
add_if "$is_primary_os"     sloccount

### OpenWRT ImageBuilder dependencies
#add_if "$is_server"         libncurses5-dev libncursesw5-dev  # <- transitional
add_if "$is_server"         libncurses-dev
add_if "$is_server"         zlib1g-dev
add_if "$is_server"         libssl-dev
add_if "$is_server"         xsltproc
add_if always               gawk
add_if always               unzip
add_if "$is_server"         gettext

### file versioning, comparison and whatnot
add_if always               git git-svn subversion
add_if "!$is_headless"      meld

### local network and maintenance tools
add_if always               sshfs

### Internet tools
add_if "!$is_headless"      chromium
add_if always               whois bind9-dnsutils
# youtube-dl is installed from upstream because Debian version is very old

### media tools
add_if "!$is_vm"            atomicparsley libmp3-tag-perl
add_if "!$is_headless"      audacity
add_if "!$is_headless"      musescore
add_if "!$is_vm"            vorbis-tools ogmtools
add_if "!$is_vm"            jhead libimage-exiftool-perl exiv2
add_if "!$is_headless"      paprefs
add_if "!$is_vm"            sox libsox-fmt-all
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
add_if "!$is_headless"      devede
# bombono? (not installable)

#### CD/DVD burninating
add_if "!$is_vm"            genisoimage xorriso
add_if "!$is_vm"            wodim cdrskin cdrdao cue2toc
add_if "!$is_headless"      k3b brasero xfburn
add_if "!$is_vm"            libcdio-utils
add_if "!$is_vm"            cdck

#### CD ripping and encoding

add_if "$is_media"          abcde
add_if "$is_media"          cdparanoia
add_if "$is_media"          lame fdkaac

### PDF tools
add_if "!$is_vm"            pdftk-java
add_if "$is_bert_desktop"   texlive-extra-utils  # pdfjam, pdfbook and friends
add_if "!$is_headless"      xournal

### other document tools
add_if "$is_bert_desktop"   pandoc
add_if "$is_primary_os"     librecad

#### 32-bit compat (for e.g. Brother binaries)
#if is_selected "$is_server"; then
#    dpkg --add-architecture i386
#    # ...redo "apt update" if necessary...
#fi
add_if "$is_server"         libc6:i386

# Minecraft and MultiMC deps
add_if "$is_multiuser"      libcurl4
# removed in bullseye, no longer needed by recent MultiMC:
##add_if "$is_multiuser"      qt5-default
# extracted locally: jdk-8u###-ojdkbuild-linux-x64
add_if "$is_multiuser"      acct  # needed to track L
add_if "$is_multiuser"      at  # needed to manage L

### PROPRIETARY, installed locally:
# Brother: hll8350cdwlpr hll8350cdwcupswrapper

$apt_install "${packages[@]}"
#for i in "${packages[@]}"; do echo "+++ $i"; $apt_install "$i"; done
