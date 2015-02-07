#!/bin/sh
#page=Kids_Court_2015_Practice_Materials
#destination='?destination=node/220'
page=welcome
destination='?destination=node/52'

wget --save-cookies cookies.txt \
    --post-data 'name=ncfo-cast&pass='"`cat .pw`"'&op=Log%20in&form_build_id=form-UxU-UF5ijwcy4XpAIMFiw36_QhyfGzmlJNXen3Z0Vfs&form_id=user_login_block' \
    -O /dev/null \
    http://www.familyopera.org/drupal/"$page""$destination"
