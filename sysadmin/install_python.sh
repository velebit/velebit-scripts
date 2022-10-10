#!/bin/bash

py_install='pip3 install --disable-pip-version-check -U'

packages=()

packages+=( \
    scipy numpy matplotlib \
    sympy \
)
packages+=( \
    imageio imageio-ffmpeg \
    eyed3 \
    grako `# dependency for eyeD3\'s "display" plugin` \
)
packages+=( \
    regex \
)
packages+=( \
    unidecode \
)
packages+=( \
    speedtest-cli \
)
packages+=( \
    beautifulsoup4 \
)
packages+=( \
    youtube-dl yt-dlp \
)
packages+=( \
    rgain \
)

$py_install "${packages[@]}"
