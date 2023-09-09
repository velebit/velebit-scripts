#!/bin/bash

flatpak="flatpak"
flatpak_install="$flatpak install"
#flatpak_install="$flatpak install --no-pull --no-deploy"

flathub_packages=()

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
            flathub_packages+=("$i")
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

$flatpak remote-add --if-not-exists \
	 flathub https://flathub.org/repo/flathub.flatpakrepo

#### system
add_if always               com.github.tchx84.Flatseal
#add_if ...                  com.gitlab.davem.ClamTk

### medical imaging tools
add_if "$is_server"         br.gov.cti.invesalius
#add_if "$is_server"         io.github.nroduit.Weasis
#add_if "$is_server"         com.github.AlizaMedicalImaging.AlizaMS

### media tools
add_if "!$is_headless"      org.musicbrainz.Picard
add_if "!$is_headless"      org.darktable.Darktable
add_if "!$is_headless"      org.inkscape.Inkscape
add_if "!$is_headless"      org.kde.digikam
add_if "$is_media"          io.github.Soundux

### PDF tools (and related)
add_if "!$is_headless"      net.scribus.Scribus
add_if "$is_bert_desktop"   xyz.rescribe.rescribe
add_if "$is_bert_desktop"   org.gnome.OCRFeeder

#### video editing
add_if "$is_media"          io.github.jliljebl.Flowblade

#### 3D modeling
add_if "$is_media"          org.blender.Blender
add_if "$is_media"          net.meshlab.MeshLab
add_if "$is_media"          io.github.f3d_app.f3d
add_if "$is_media"          org.openscad.OpenSCAD
add_if "$is_media"          com.ultimaker.cura
add_if "$is_media"          com.flashforge.FlashPrint
add_if "$is_media"          com.prusa3d.PrusaSlicer

#### comms
add_if "!$is_headless"      com.discordapp.Discord
add_if "!$is_headless"      org.signal.Signal
add_if "$is_multiuser"      com.skype.Client
add_if "$is_multiuser"      us.zoom.Zoom
add_if "$is_multiuser"      com.slack.Slack

#### games
#add_if "$is_multiuser"      com.mojang.Minecraft # <- local manual install
add_if "$is_multiuser"      io.mrarm.mcpelauncher
add_if "$is_multiuser"      edu.mit.Scratch
add_if "$is_multiuser"      org.scummvm.ScummVM
add_if "$is_multiuser,$is_bert_desktop" com.valvesoftware.Steam
add_if "$is_multiuser"      org.flightgear.FlightGear
add_if "$is_multiuser"      com.endlessnetwork.passage

#### development and electronics
add_if "$is_multiuser"      cc.arduino.arduinoide
add_if "$is_multiuser"      org.fritzing.Fritzing

#### notes
add_if "!$is_headless"      md.obsidian.Obsidian

$flatpak_install flathub "${flathub_packages[@]}"
