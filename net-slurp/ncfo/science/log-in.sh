#!/bin/sh
wget --save-cookies cookies.txt \
    --post-data 'name=ncfo-chorus&pass='"`cat .pw`"'&op=Log%20in&form_build_id=form-e07efccc46c8bdf81109e1eed6ecaa8d&form_id=user_login_block' \
    -O /dev/null \
    'http://www.familyopera.org/drupal/node/142'
