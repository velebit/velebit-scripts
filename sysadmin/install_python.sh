#!/bin/bash

py_install='pip3 install --disable-pip-version-check -U'

packages=()

#packages+=( \
#    pip \
#)
packages+=( \
    black mypy
)
packages+=( \
    scipy numpy matplotlib \
    sympy \
)
packages+=( \
    imageio imageio-ffmpeg \
    eyed3 music_tag \
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
packages+=( \
    pyluach \
    `# hebcal` \
    python-dateutil convertdate \
)
packages+=( \
    ics
)
packages+=( \
    pybotics \
    pytransform3d \
    roboticstoolbox-python \
)

$py_install "${packages[@]}"
