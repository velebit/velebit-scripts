#!/bin/bash
# THIS FILE HAS BEEN SUPPLANTED BY VENV CONFIGURATION IN
# .local/lib/python/venv/requirements.default_000.txt

#py_install='pip3 install --disable-pip-version-check -U'

dump () {
    for i in "$@"; do echo "$i"; done | sort | uniq
}
py_install=dump

packages=()

# future me, you should do this only sometimes:
#packages+=( \
#    pip setuptools wheel \
#)
packages+=( \
    black mypy \
    flake8 \
)
packages+=( \
    scipy numpy matplotlib \
    sympy \
)
packages+=( \
    imageio imageio-ffmpeg \
    eyed3 music_tag \
    grako `# <= dependency for eyeD3\'s "display" plugin` \
)
packages+=( \
    regex \
)
packages+=( \
    unidecode \
    pdf2txt \
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
#packages+=( \
#    flexget \
#)
packages+=( \
    rgain \
)
packages+=( \
    pyluach \
    `# hebcal` \
    python-dateutil convertdate dateparser \
)
packages+=( \
    ics
)
packages+=( \
    pybotics \
    pytransform3d \
    roboticstoolbox-python \
)
packages+=( \
    py-trello \
)
packages+=( \
    feedparser \
    feedgen \
)
packages+=( \
    markdown \
    cactus mkdocs pelican 'pelican[markdown]' 'Nikola[extras]' \
    `# hyde <= 0.8.x imposes dependency on very old markdown` \
)

# Packages that once upon a time had scripts installed in .local/bin,
# either directly as dependencies
##packages+=( \
##    cheroot \
##    cherrypy \
##    commonmark \
##    coverage \
##    flask \
##    guessit \
##    rpyc \
##    tempora \
##    zxcvbn \
##)

$py_install "${packages[@]}"
