#!/bin/bash

flatpak="flatpak"
flatpak_install="$flatpak install"
#flatpak_install="$flatpak install --no-pull --no-deploy"

flathub_packages=()

is_selected () {
    local IFS=', '
    for i in $*; do
	case "$i" in
	    always|yes|!no|!!yes|!!!no)
		return 0 ;;   # true
	    ''|no|!yes|!!no|!!!yes)
		: ;;          # keep going
	    *)
		echo "Warning: invalid selection value '$i'" >&2
		: ;;          # keep going
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

is_server=yes
is_media=yes
is_multiuser=

$flatpak remote-add --if-not-exists \
	 flathub https://flathub.org/repo/flathub.flatpakrepo

#### system
add_if "$is_multiuser"      com.github.tchx84.Flatseal
#add_if ...                  com.gitlab.davem.ClamTk

### medical imaging tools
add_if "$is_server"         br.gov.cti.invesalius

#### video editing
add_if "$is_media"          io.github.jliljebl.Flowblade

#### comms
add_if always               com.discordapp.Discord
add_if always               org.signal.Signal
add_if "$is_multiuser"      com.skype.Client
add_if "$is_multiuser"      us.zoom.Zoom
add_if "$is_multiuser"      com.slack.Slack

#### games
#add_if "$is_multiuser"      com.mojang.Minecraft # <- local manual install
add_if "$is_multiuser"      io.mrarm.mcpelauncher
add_if "$is_multiuser"      edu.mit.Scratch
add_if "$is_multiuser"      org.scummvm.ScummVM
add_if "$is_multiuser"      com.valvesoftware.Steam

$flatpak_install flathub "${flathub_packages[@]}"
