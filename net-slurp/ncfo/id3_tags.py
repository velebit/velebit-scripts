#!/usr/bin/python3

import argparse
import eyed3
import eyed3.id3
import glob
import multiprocessing
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
    group.add_argument('-W', '--wipe', action='store_const',
                       dest='remove_version', default=eyed3.id3.ID3_V1,
                       const=eyed3.id3.ID3_ANY_VERSION)
    group.add_argument('-k', '--keep', action='store_const',
                       dest='remove_version', default=eyed3.id3.ID3_V1,
                       const=None)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-3', '--2.3', action='store_const',
                       dest='out_version', default=eyed3.id3.ID3_V2_3,
                       const=eyed3.id3.ID3_V2_3)
    group.add_argument('-4', '--2.4', action='store_const',
                       dest='out_version', default=eyed3.id3.ID3_V2_3,
                       const=eyed3.id3.ID3_V2_4)
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

def skip_error_line(line, verbose):
    return (verbose < 1 and
            re.search(r"Frame 'RVA2' is not yet supported", line))

def get_tag_args(remove_version, out_version):
    if remove_version is None:
        remove_args = ()
    elif remove_version == eyed3.id3.ID3_V1:
        remove_args = ('--remove-v1',)
    elif remove_version == eyed3.id3.ID3_V2:
        remove_args = ('--remove-v2',)
    elif remove_version == eyed3.id3.ID3_ANY_VERSION:
        remove_args = ('--remove-all',)
    else:
        print("Unknown remove_version ", remove_version)
        remove_args = ()
    if out_version == eyed3.id3.ID3_V2_3:
        version_args = ('--to-v2.3',)
    elif out_version == eyed3.id3.ID3_V2_4:
        version_args = ('--to-v2.4',)
    else:
        print("Unknown out_version ", out_version)
        version_args = ('--to-v2.3',)
    return remove_args + version_args

def update_file_tags(data):
    with open(data['log'], 'a') as logfile:
        file = data['file']
        print(f"Updating tags for {file}...", file=logfile)
        orig_stat = os.stat(file)
        if data['remove_version'] is not None:
            eyed3.id3.Tag.remove(file, version=data['remove_version'])
        id3file = eyed3.load(file)
        if not id3file:
            print(f"Could not load {file}!", file=logfile)
            print(f"Could not load {file}!", file=sys.stderr)
            return
        if not id3file.tag:
            id3file.initTag(version=data['out_version'])
        assert id3file.tag
        id3file.tag.title = data['name']
        id3file.tag.artist = data['artist']
        id3file.tag.album = data['album']
        id3file.tag.track_num = (data['track'], data['num_tracks'])
        id3file.tag.save(version=data['out_version'],
                         encoding=None,  # or select based on out_version?
                         max_padding=(64*1024))
        os.utime(file, ns=(orig_stat.st_atime_ns, orig_stat.st_mtime_ns))
        #print(result.stdout, end='', file=logfile)
        #print(result.stderr, end='', file=logfile)
        #if data['verbose'] >= 2:
        #    print(result.stdout, end='', file=sys.stdout)
        #for line in re.split(r'(?<=\n)', result.stderr):
        #    if not skip_error_line(line, data['verbose']):
        #        print(line, end='', file=sys.stderr)

command_queue = []

def queue_tags_from_playlist(playlist, settings, log=os.devnull):
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

    num_tracks = len(tracks)
    for i in range(len(tracks)):
        track = i+1
        file = tracks[i]
        name = os.path.splitext(os.path.basename(file))[0]
        name = settings.id3_track_strip(name)
        data = { 'file': file, 'name': name, 'artist': settings.id3_artist,
                 'album': album, 'track': track, 'num_tracks': num_tracks,
                 'remove_version': settings.remove_version,
                 'out_version': settings.out_version,
                 'log': log, 'verbose': settings.verbose }
        if settings.dry_run:
            print(f"WOULD update tags for {file}")
        else:
            global command_queue
            command_queue.append(data)

def process_queue():
    global command_queue

    try:
        num_available_cores = len(os.sched_getaffinity(0))
        num_processes = int(num_available_cores * 1.5 + 0.01)
    except:
        print("Could not get available cores, defaulting to 1 process!",
              file=sys.stderr)
        num_processes = 1

    print("Processing tags...")
    if num_processes == 1:
        for data in command_queue:
            update_file_tags(data)
    else:
        with multiprocessing.Pool(processes=num_processes) as pool:
            pool.map(update_file_tags, command_queue)
            pool.close()

def default_playlists():
    return [p for p in sorted(glob.glob('*.m3u'))
            if not re.search(r'(?:^|\s)X-', p)]

def process_playlist(playlist, settings):
    print(f"Preparing tags for playlist {settings.dir_prefix}{playlist}...")
    log = 'id3_tags.' + os.path.basename(playlist) + '.log'
    try:
        os.unlink(log)
    except FileNotFoundError:
        pass
    queue_tags_from_playlist(playlist, settings, log=log)

def process_playlist_args(args, settings):
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
    process_queue()

if __name__ == "__main__":
    main()
