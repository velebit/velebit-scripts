#!/usr/bin/python3

from pathlib import Path
import re
import sys

from letter_numbers import decompose, string_to_number


def find_collisions(input: Path) -> None:
    lookup: dict[str, dict[str, set[str]]] = {}
    with open(input, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip()
            word = line.lower()
            if not re.search(r"[^a-z]", word):
                for encoding in decompose(word, string_to_number):
                    if encoding not in lookup:
                        lookup[encoding] = {word: {line}}
                    elif word not in lookup[encoding]:
                        lookup[encoding][word] = {line}
                    else:
                        lookup[encoding][word].add(line)
    for encoding in sorted(lookup.keys()):
        # If lookup[encoding] has only one key, that means that either there's only
        # one word that maps to this encoding, or multiple words that differ only in case.
        if len(lookup[encoding]) >= 2:
            # First sort puts capitalized versions of words after lowercase ones
            words = sorted(
                {word for group in lookup[encoding].values() for word in group},
                reverse=True,
            )
            words = sorted(words, key=lambda w: w.lower())
            pretty_list = [e for word in words for e in (repr(word), ", ")]
            pretty_list.pop()
            pretty_list[-2] = " or "
            print(f"Encoding {encoding!r} can represent {''.join(pretty_list)}")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: letter_numbers.py <word_file> [<word_file>...]")
        print("  where <word_file> should be a file containing one word per line.")
        sys.exit(1)
    for text in sys.argv[1:]:
        find_collisions(Path(text))


if __name__ == "__main__":
    main()
