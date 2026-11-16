#!/usr/bin/env python3

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import List, Set, Tuple
from urllib.parse import unquote_to_bytes, urlsplit


def local_name(url: str) -> str:
    encoded_name = urlsplit(url).path.rsplit("/", 1)[-1]
    if not encoded_name:
        encoded_name = "index.html"

    name = os.fsdecode(unquote_to_bytes(encoded_name))
    restricted = bytearray()
    for byte in os.fsencode(name):
        if byte < 32 or byte in b'<>:"/\\|?*':
            restricted.extend(f"%{byte:02X}".encode("ascii"))
        else:
            restricted.append(byte)

    name = os.fsdecode(bytes(restricted))
    while name.endswith((".", " ")):
        name = name[:-1] + f"%{ord(name[-1]):02X}"
    return name or "index.html"


def files_in(directory: Path) -> List[Path]:
    return [entry for entry in directory.iterdir() if entry.is_file()]


def prune_cache(cache_root: Path, active_ids: Set[str]) -> None:
    for entry in cache_root.iterdir():
        if (
            entry.is_dir()
            and not entry.is_symlink()
            and len(entry.name) == 64
            and all(char in "0123456789abcdef" for char in entry.name)
            and entry.name not in active_ids
        ):
            shutil.rmtree(entry)


def publish(cache_file: Path, destination: Path) -> None:
    temporary = destination.with_name(f".{destination.name}.{os.getpid()}.tmp")
    temporary.unlink(missing_ok=True)
    try:
        try:
            os.link(cache_file, temporary)
        except OSError:
            shutil.copy2(cache_file, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def run_wget(url: str, cache_dir: Path, cookies: str) -> Tuple[int, bool]:
    command = [
        "wget",
        "--load-cookies",
        cookies,
        "-nd",
        "-P",
        str(cache_dir),
        "-N",
        "--restrict-file-names=windows",
        "--progress=bar:force",
        url,
    ]
    process = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    output = bytearray()
    stdout = process.stdout
    if stdout is None:
        process.kill()
        process.wait()
        raise RuntimeError("Wget stdout pipe was not created")
    while True:
        chunk = os.read(stdout.fileno(), 65536)
        if not chunk:
            break
        output.extend(chunk)
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
    return process.wait(), b"Saving to:" in output


def write_manifest(path: Path, references: List[Tuple[str, str]]) -> None:
    with path.open("w", encoding="utf-8", errors="surrogateescape") as manifest:
        for kind, filename in references:
            if "\t" in filename or "\n" in filename or "\r" in filename:
                raise ValueError(
                    f"Unsupported control character in filename: {filename!r}"
                )
            manifest.write(f"{kind}\t{filename}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url-list", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--cookies", required=True)
    parser.add_argument("--reference-file", required=True)
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    cache_root = output_dir / ".wget-cache"
    cache_root.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    reference_file = Path(args.reference_file)
    reference_file.unlink(missing_ok=True)

    urls = [
        line.strip()
        for line in Path(args.url_list)
        .read_text(encoding="utf-8", errors="surrogateescape")
        .splitlines()
        if line.strip()
    ]

    references: List[Tuple[str, str]] = []
    occupied_names: Set[str] = set()
    active_ids: Set[str] = set()
    failures = 0
    for url in urls:
        base_name = local_name(url)
        destination_name = base_name
        suffix = 1
        while destination_name in occupied_names:
            destination_name = f"{base_name}.{suffix}"
            suffix += 1
        occupied_names.add(destination_name)

        destination = output_dir / destination_name
        url_id = hashlib.sha256(
            url.encode("utf-8", errors="surrogateescape")
        ).hexdigest()
        active_ids.add(url_id)
        cache_dir = cache_root / url_id
        cache_dir.mkdir(parents=True, exist_ok=True)

        return_code, downloaded = run_wget(url, cache_dir, args.cookies)
        cached_files = files_in(cache_dir)
        if len(cached_files) > 1:
            print(
                f"Expected one Wget cache file for {url!r}, found {len(cached_files)}",
                file=sys.stderr,
            )
            if destination.exists():
                references.append(("keep", str(destination)))
            failures += 1
            continue

        if cached_files and return_code == 0:
            try:
                publish(cached_files[0], destination)
            except OSError as error:
                print(
                    f"Could not publish {destination}: {error}",
                    file=sys.stderr,
                )
                failures += 1
                continue
            references.append(("new" if downloaded else "keep", str(destination)))
        elif destination.exists():
            references.append(("keep", str(destination)))

        if return_code:
            failures += 1

    if not failures:
        prune_cache(cache_root, active_ids)
    write_manifest(reference_file, references)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
