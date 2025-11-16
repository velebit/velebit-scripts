#!/bin/bash

source "$(dirname "$0")/_uri.sh"

#page=welcome
#destination='?destination=node/52'
page=welcome
destination=

if ! [[ -f .pw ]]; then
    echo "Please put the password into the incredibly secure .pw file!" >&2
    exit 1
fi

wget --save-cookies cookies.txt \
    --post-data 'name=ncfo-cast&pass='"`cat .pw`"'&op=Log%20in&form_build_id=form-UxU-UF5ijwcy4XpAIMFiw36_QhyfGzmlJNXen3Z0Vfs&form_id=user_login_block' \
    -O /dev/null \
    "${base_uri}/${page}${destination}"

if [[ -n "$(grep -E '^(#HttpOnly_)?www.familyopera.org' cookies.txt)" ]]; then
    echo "Login successful!"
else
    echo "No cookies; login failed." >&2
    exit 1
fi