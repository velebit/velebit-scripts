#!/usr/bin/python3

import argparse
import multiprocessing
import os
import os.path
import re
import shutil
import subprocess
import sys

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
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        '--skip-missing', dest='skip_missing', action='store_true',
        default=None, help="Skip any missing files in the processing list.")
    group.add_argument(
        '--no-skip-missing', dest='skip_missing', action='store_false',
        default=None, help="Fail immediately on any missing files.  [Default.]")
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

# wrapper so we don't try pickling sys.stderr... =)
def print_stderr(*args):
    print(*args, file=sys.stderr)

def run_or_fail(cmd):
    subprocess.run(cmd, check=True)
def run_or_warn(cmd, warning):
    rc = subprocess.run(cmd, check=False).returncode
    if rc != 0:
        print(warning + ".", file=sys.stderr)

command_list = []
commands_for_input = {}

def queue_file(inf, outf, settings):
    global command_list, commands_for_input

    process_directory(os.path.dirname(outf), settings)

    if inf in commands_for_input:
        entry = commands_for_input[inf]
        if outf in entry[2]:
            entry[3].append((print_stderr, (f"-!- {outf}",)))
        else:
            entry[3].append((print_stderr, (f"-+- {outf}",)))
            entry[3].append((shutil.copyfile, (entry[1], outf) ))
            entry[3].append((os.utime, (outf,), {'ns': (entry[4].st_atime_ns,
                                                        entry[4].st_mtime_ns)}))
            entry[2].add(outf)
    else:
        entry = (inf, outf, {outf}, [], os.stat(inf))
        command_list.append(entry)
        commands_for_input[inf] = entry
        entry[3].append((print_stderr, (f"--- {outf}",)))
        entry[3].append((shutil.copyfile, (inf, outf) ))
        if re.search(r'\.mp3$', inf, re.IGNORECASE):
            if settings.wipe_id3:
                entry[3].append((run_or_warn,
                                 (('./id3wipe', '-f', outf),
                                  f"id3wipe ({outf}) failed") ))
            if settings.adjust_gain:
                entry[3].append((run_or_warn,
                                 (('replaygain', '-f', outf),
                                  f"replaygain ({outf}) failed") ))
        entry[3].append((os.utime, (outf,), {'ns': (entry[4].st_atime_ns,
                                                    entry[4].st_mtime_ns)}))

def run_entry(entry):
    for cmd in entry[3]:
        if len(cmd) >= 2 and cmd[1] is not None:
            if len(cmd) >= 3 and cmd[2] is not None:
                cmd[0](*cmd[1], **cmd[2])
            else:
                cmd[0](*cmd[1])
        else:
            if len(cmd) >= 3 and cmd[2] is not None:
                cmd[0](**cmd[2])
            else:
                cmd[0]()
    return None

def process_queue():
    global command_list

    def ncmds(entry):
        return -len(entry[3])
    queue = sorted(command_list, key=ncmds)

    try:
        num_available_cores = len(os.sched_getaffinity(0))
        num_processes = int(num_available_cores * 2 + 0.01)
    except:
        print("Could not get available cores, defaulting to 1 process!",
              file=sys.stderr)
        num_processes = 1

    if num_processes == 1:
        for entry in queue:
            run_entry(entry)
    else:
        with multiprocessing.Pool(processes=num_processes) as pool:
            pool.map(run_entry, queue)
            pool.close()

def main():
    settings = parse_args()
    for line in sys.stdin:
        line = line.rstrip("\r\n")
        try:
            (inf, outf) = line.split('=')
        except ValueError as ve:
            ve.args = ((ve.args[0] + f"; input was line={line!r}",)
                       + ve.args[1:])
            raise
        try:
            queue_file(inf, outf, settings)
        except FileNotFoundError as fnfe:
            if settings.skip_missing:
                print_stderr(f"File not found, ignored: {outf}")
            else:
                raise
    process_queue()

if __name__ == "__main__":
    main()
