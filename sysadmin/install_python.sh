#!/bin/bash

py_install='pip3 install --disable-pip-version-check -U'

packages=()

packages+=( \
    scipy numpy matplotlib \
)
packages+=( \
    imageio imageio-ffmpeg \
    eyed3 \
)
packages+=( \
    regex \
)
packages+=( \
    unidecode \
)
packages+=( \
    speedtest-cli
)

$py_install "${packages[@]}"
