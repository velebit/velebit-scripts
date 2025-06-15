#!/usr/bin/python3
import argparse
import os
import re
import subprocess


def fix_up_env():
    if 'LANG' not in os.environ:
        os.environ['LANG'] = 'en_US.UTF-8'


def go_to_dir(working_dir, expected_path):
    os.chdir(working_dir)
    if expected_path is not None:
        assert os.path.exists(expected_path), f"Error: {expected_path} missing"


def go_to_script_dir():
    go_to_dir(os.path.dirname(__file__),
              os.path.basename(__file__))


DEFAULT_EXCLUDED_PATTERNS = (
    '*.sh', '*.py', '*~', 'mb-album-ids', '*.m3u', '*.wpl', '*.jpg'
)


def make_zip(zipfile, inputs,
             excluded_patterns=DEFAULT_EXCLUDED_PATTERNS,
             excluded_paths=()):
    inputs = tuple(inputs)
    if len(inputs) == 0:
        raise ValueError("No input file specified.")
    try:
        os.remove(zipfile)
    except FileNotFoundError:
        pass
    cmd = ['7z', 'a', zipfile, *inputs,
           *[f"-xr!{x}" for x in excluded_patterns],
           *[f"-x!{x}" for x in excluded_paths],
           ]
    subprocess.run(cmd, check=True)


def to_abs(*dirs):
    base = os.path.dirname(__file__)
    return tuple((os.path.abspath(os.path.join(base, d))
                  for d in dirs))


def build_ignores(base, top, paths):
    regex = r'^' + re.escape(top) + r'/'
    relative_ignores = [os.path.relpath(p, start=base)
                        for p in paths]
    return [i for i in relative_ignores if re.search(regex, i)]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-x', '--exclude', action='append', default=[],
                        metavar='EXCLUDE_PATH')
    parser.add_argument('include', nargs='+',
                        metavar='INCLUDE_PATH')
    return parser.parse_args()


def main():
    fix_up_env()
    base = os.path.basename(os.path.abspath(os.path.dirname(__file__)))
    top_path = to_abs('.')[0]
    parent_path = os.path.dirname(top_path)
    zipdir_path = os.path.join(parent_path, 'zip')
    args = parse_args()
    print(args)
    dirs = to_abs(*args.include)
    ignored = to_abs(*args.exclude)
    for d in dirs:
        curr_name = os.path.basename(d)
        curr_parent = os.path.dirname(d)
        if d == top_path:
            zip_name = f"{base}-custom.zip"
        else:
            dfrag = re.sub(r'_*-_*', '-', re.sub(r'[/ ]+', '_',
                                                 os.path.basename(d)))
            zip_name = f"{base}-custom-{dfrag}.zip"
        zip_path = os.path.relpath(
            os.path.join(zipdir_path, zip_name),
            start=curr_parent)
        go_to_dir(curr_parent, curr_name)
        make_zip(zip_path, [curr_name],
                 excluded_paths=build_ignores(curr_parent, curr_name,
                                              dirs + ignored))


if __name__ == "__main__":
    main()
