#!/usr/bin/python3

import argparse
import os.path
import re
import subprocess
from sys import stdin, stdout, stderr

def parse_args():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        '--gain', dest='adjust_gain', action='store_true', default=False,
        help="Attempt to level track gains using replaygain.")
    group.add_argument(
        '--no-gain', dest='adjust_gain', action='store_false', default=False,
        help="Don't attempt to level track gains.  [Default.]")
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        '--wipe', dest='wipe_id3', action='store_true', default=None,
        help=("Attempt to clear ID3 tags (track names, gain info...) from"
              " MP3 files.  [Default with --gain.]"))
    group.add_argument(
        '--no-wipe', dest='wipe_id3', action='store_false', default=None,
        help="Don't attempt to clear ID3 tags.  [Default with --no-gain.]")
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        '--remove', dest='remove_old', action='store_true', default=True,
        help="Remove everything in the old destination directory.  [Default.]")
    group.add_argument(
        '--no-remove', dest='remove_old', action='store_false', default=True,
        help="Don't remove everything in old destination directory.")
    settings = parser.parse_args()
    if settings.wipe_id3 is None:
        settings.wipe_id3 = settings.adjust_gain
    return settings

seen_outdir = set()

def process_directory(outdir, settings):
    if settings.remove_old:
        global seen_outdir
        if outdir not in seen_outdir:
            if os.path.lexists(outdir):
                print(f"Removing {outdir}")
                subprocess.run(['rm', '-rf', outdir], check=True)
            seen_outdir.add(outdir)

    if not os.path.isdir(outdir):
        subprocess.run(['mkdir', '-p', outdir], check=True)

already_processed = {}

def process_file(inf, outf, settings):
    process_directory(os.path.dirname(outf), settings)

    global already_processed
    if inf in already_processed:
        if already_processed[inf] == outf:
            print(f"-!- {outf}", file=stderr)
        else:
            print(f"-+- {outf}", file=stderr)
            subprocess.run(['cp', '--preserve=timestamps',
                            already_processed[inf], outf], check=True)
    else:
        print(f"--- {outf}", file=stderr)
        subprocess.run(['cp', '--preserve=timestamps', inf, outf], check=True)
        if re.search(inf, r'\.mp3$', re.IGNORECASE):
            if settings.wipe_id3:
                if subprocess.run(['./id3wipe', '-f', outf],
                                  check=False).returncode != 0:
                    print(f"id3wipe ({outf}) failed.", file=stderr)
            if settings.adjust_gain:
                if subprocess.run(['replaygain', '-f', outf],
                                  check=False).returncode != 0:
                    print(f"replaygain ({outf}) failed.", file=stderr)
            if settings.wipe_id3 or settings.adjust_gain:
                if subprocess.run(['touch', '-r', inf, outf],
                                  check=False).returncode != 0:
                    print(f"Updating timestamp ({outf}) failed.", file=stderr)
            already_processed[inf] = outf

def main():
    settings = parse_args()
    for line in stdin:
        line = line.rstrip("\r\n")
        try:
            (inf, outf) = line.split('=')
        except ValueError as ve:
            raise ValueError("bad input format in '{line}': {ve}")
        process_file(inf, outf, settings)

if __name__ == "__main__":
    main()
