#!/bin/sh
#page=welcome
#destination='?destination=node/52'
page=welcome
destination=

wget --save-cookies cookies.txt \
    --post-data 'name=ncfo-cast&pass='"`cat .pw`"'&op=Log%20in&form_build_id=form-UxU-UF5ijwcy4XpAIMFiw36_QhyfGzmlJNXen3Z0Vfs&form_id=user_login_block' \
    -O /dev/null \
    http://www.familyopera.org/drupal/"$page""$destination"
