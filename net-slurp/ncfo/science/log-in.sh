#!/bin/sh
#page=node/197
#page=2014_Powers_of_Ten_Practice_MP3s
page=welcome
destination='?destination=node/52'

wget --save-cookies cookies.txt \
    --post-data 'name=ncfo-chorus&pass='"`cat .pw`"'&op=Log%20in&form_build_id=form-e07efccc46c8bdf81109e1eed6ecaa8d&form_id=user_login_block' \
    -O /dev/null \
    http://www.familyopera.org/drupal/"$page""$destination"
