#!/bin/sh

install='apt install --no-upgrade'
#install='apt install --no-upgrade --install-suggests'
#install="`dirname "$0"`/check-package-recommends"

## OS, desktop environment, system maintainenace and diagnostics
$install \
    bash-completion \
    emacs \
    smartmontools nvme-cli sysstat \
    discover hdparm \
    mdadm \
    cryptsetup-bin cryptsetup-run keyutils \
    perl perl-doc \
    python3 ipython3 python3-pip \
    python3-tk \
    graphviz \
    iputils-ping traceroute telnet netcat-traditional \
    tcpdump dhcpdump wireshark nmap \
    lsof iotop \
    task-desktop task-ssh-server \
    task-print-server foomatic-db-engine printer-driver-all openprinting-ppds \
    cups printer-driver-cups-pdf \
    task-xfce-desktop task-cinnamon-desktop \
    gconf-editor \
    isc-dhcp-server \
    samba \
    rsync \
    screen

#    xfce4-mixer \
# no need for crypt disk setup at boot (cryptsetup, cryptsetup-initramfs)

## development and the like
$install \
    gcc g++ \
    strace
$install \
    libhtml-element-extended-perl libhtml-tableextract-perl \
    libtext-unidecode-perl libtext-unaccent-perl

### file versioning, comparison and whatnot
$install \
    git git-svn subversion \
    meld

### Internet tools
$install \
    chromium \
    whois dnsutils
# Installed from upstream because Debian version is very old:
#    youtube-dl

### media tools
$install \
    eyed3 atomicparsley \
    python-rgain \
    picard \
    audacity \
    musescore \
    jhead libimage-exiftool-perl exiv2 \
    libsox-fmt-all \
    darktable \
    blender

#### video editing
$install \
    openshot \
    flowblade \
    olive-editor

# pitivi? (installable)
# lives/LiVES? (installable)
# shotcut? (snap)

#### DVD creation
$install \
    devede
# bombono? (not installable)

### PDF tools
$install \
    xournal

#### 32-bit compat (for e.g. Brother binaries)
dpkg --add-architecture i386
# ...redo "apt update" if necessary...
$install \
    libc6:i386

##
#$install \
#    virtualbricks

### PROPRIETARY, installed locally:
# Brother: hll8350cdwlpr hll8350cdwcupswrapper
