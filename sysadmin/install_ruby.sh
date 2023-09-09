#!/bin/bash

rb_install='gem install --verbose --user-install --development'

packages=()

# future me, you should do this only sometimes:
#packages+=( \
#    gem
#)
packages+=( \
    middleman \
)

$rb_install "${packages[@]}"
