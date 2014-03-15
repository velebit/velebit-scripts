#!/bin/sh
#PAGE_DIR=node/197
PAGE_DIR=2014_Powers_of_Ten_Practice_MP3s
wget --save-cookies cookies.txt \
    --post-data 'name=ncfo-chorus&pass='"`cat .pw`"'&op=Log%20in&form_build_id=form-e07efccc46c8bdf81109e1eed6ecaa8d&form_id=user_login_block' \
    -O /dev/null \
    http://www.familyopera.org/drupal/"$PAGE_DIR"/
