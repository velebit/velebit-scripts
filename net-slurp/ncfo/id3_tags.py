#!/usr/bin/python3

import argparse
import contextlib
import glob
import os
import os.path
import re
import subprocess
import sys

def get_default_album_prefix():
    return os.path.basename(os.path.dirname(os.getcwd())) + ': '
def get_default_num_processes():
    try:
        num_available_cores = len(os.sched_getaffinity(0))
        num_processes = int(num_available_cores * 2 + 0.01)
    except:
        print("Could not get available cores, defaulting to 1 process!",
              file=sys.stderr)
        num_processes = 1
    return num_processes

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-n', '--dry-run', action='store_true')
    parser.add_argument('-v', '--verbose', action='count', default=0)
    parser.add_argument('-a', '--id3-artist', action='store',
                        metavar='ARTIST', default="NCFO practice")
    parser.add_argument('-p', '--id3-album-prefix', action='store',
                        metavar='PREFIX', default=get_default_album_prefix())
    parser.add_argument('-s', '--id3-album-suffix', action='store',
                        metavar='SUFFIX', default=" practice")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-xx', '--id3-playlist-strip-none',
                       action='store_const', dest='id3_playlist_strip',
                       const=keep_all, default=None)
    group.add_argument('-xw1', '--id3-playlist-keep-word1',
                       action='store_const', dest='id3_playlist_strip',
                       const=make_keep_word(1), default=None)
    group.add_argument('-xw2', '--id3-playlist-keep-word2',
                       action='store_const', dest='id3_playlist_strip',
                       const=make_keep_word(2), default=None)
    group.add_argument('-xw3', '--id3-playlist-keep-word3',
                       action='store_const', dest='id3_playlist_strip',
                       const=make_keep_word(3), default=None)
    group.add_argument('-xp', '--id3-playlist-keep-parenthesized',
                       action='store_const', dest='id3_playlist_strip',
                       const=keep_paren, default=None)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-tx', '--id3-track-strip-none',
                       action='store_const', dest='id3_track_strip',
                       const=keep_all, default=None)
    group.add_argument('-tn', '--id3-track-strip-number',
                       action='store_const', dest='id3_track_strip',
                       const=strip_number, default=None)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-W', '--wipe',
                       action='store_const', dest='old_tag_args',
                       const=('--remove-all',), default=None)
    group.add_argument('-k', '--keep',
                       action='store_const', dest='old_tag_args',
                       const=(), default=None)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-3', '--2.3',
                       action='store_const', dest='new_tag_args',
                       const=('--to-v2.3',), default=None)
    group.add_argument('-4', '--2.4',
                       action='store_const', dest='new_tag_args',
                       const=('--to-v2.4',), default=None)
    parser.add_argument('-d', '--directory', action='append',
                        dest='dir_prefix', default=[], metavar='DIR')
    parser.add_argument('-P', '--num-processes', action='store', type=int,
                        default=get_default_num_processes())
    parser.add_argument('playlists', nargs='*')

    settings = parser.parse_args()

    if settings.id3_playlist_strip is None:
        settings.id3_playlist_strip = make_keep_word(2)
    if settings.id3_track_strip is None:
        settings.id3_track_strip = keep_all
    if settings.old_tag_args is None:
        settings.old_tag_args=('--remove-v1',)
    if settings.new_tag_args is None:
        settings.new_tag_args=('--to-v2.3',)
    settings.dir_prefix = ''.join([d+"/" for d in settings.dir_prefix])

    return settings


def keep_all(text):
    return text

def make_keep_word(pos):
    def keep_word_N(text):
        return text.split()[pos]
    return keep_word_N

def keep_paren(text):
    match = re.search(r'\(([^()]*)\)', text)
    if match is None:
        return ''
    return match.group(1)

def strip_number(text):
    return re.sub(r'^[0-9][0-9]*[ _-]?', '', text)

def update_tags_from_playlist(playlist, settings, logfile=None):
    who = os.path.splitext(os.path.basename(playlist))[0]
    who = settings.id3_playlist_strip(who)
    who = re.sub(r'^X-X*', '', who, count=1)
    album = settings.id3_album_prefix + who + settings.id3_album_suffix

    # This extracts just the file names from either a M3U or WPL playlist.
    tracks = []
    with open(playlist, 'r') as file:
        for line in file:
            line = line.strip("\r\n")
            wpl_match = re.search(r'^ *<media src="([^"]*)"', line)
            if wpl_match:
                line = wpl_match.group(1)
                line = re.sub(r'\\', '/', re.sub(r'&amp;', '&', line))
            if len(line) and not re.search(r'^[#<\s]', line):
                tracks.append(line)

    num_tracks = str(len(tracks))
    for i in range(len(tracks)):
        track = str(i+1)
        file = tracks[i]
        name = os.path.splitext(os.path.basename(file))[0]
        name = settings.id3_track_strip(name)
        if logfile is not None:
            print(f"Updating tags for {file}...", file=logfile)
        cmd=(('eyeD3',) + settings.old_tag_args + settings.new_tag_args +
             ('-t', name, '-a', settings.id3_artist, '-A', album,
              '-n', track, '-N', num_tracks, '--no-color', '-Q',
              '--preserve-file-times',
              file))
        if settings.dry_run:
            print(" ".join(("WOULD run:", *cmd)))
        else:
            result = subprocess.run(
                cmd, check=False, encoding='UTF-8',
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if settings.verbose >= 2:
                print(result.stdout, end='', file=sys.stdout)
            print(result.stderr, end='', file=sys.stderr)
            if logfile is not None:
                if settings.verbose >= 0:
                    print(result.stdout, end='', file=logfile)
                print(result.stderr, end='', file=logfile)

def default_playlists():
    return [p for p in sorted(glob.glob('*.m3u'))
            if not re.search(r'(?:^|\s)X-', p)]

def process_playlist(playlist, settings):
    print(f"Updating tags for playlist {settings.dir_prefix}{playlist}...")
    log = 'id3_tags.' + os.path.basename(playlist) + '.log'
    with open(log, 'w') as logfile:
        update_tags_from_playlist(playlist, settings, logfile=logfile)

def process_playlist_args(args, settings):
    # TODO add back parallelism
    for playlist in args:
        process_playlist(playlist, settings)


def main():
    settings = parse_args()

    os.chdir("../" + settings.dir_prefix)

    if not settings.playlists:
        for l in glob.glob('id3_tags.*.log'):
            os.unlink(l)
        process_playlist_args(default_playlists(), settings)
    else:
        process_playlist_args(settings.playlists, settings)

if __name__ == "__main__":
    main()
