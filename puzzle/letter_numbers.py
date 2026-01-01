#!/usr/bin/python3

from pathlib import Path
import re
import sys


string_to_number = {chr(ord("a") - 1 + n): str(n) for n in range(1, ord("z") - 96 + 1)}
number_to_string = {n: c for c, n in string_to_number.items()}


def decompose_chars(text: str, mapping: dict[str, str]) -> list[str]:
    return ["".join(mapping[c] for c in text)]


def decompose_recursive(
    text: str, lengths: tuple[int, ...], mapping: dict[str, str]
) -> list[str]:
    if text == "":
        return [""]
    result: list[str] = []
    for length in lengths:
        if len(text) >= length:
            try:
                prefix = mapping[text[:length]]
            except KeyError:
                continue
            result.extend(
                prefix + rest
                for rest in decompose_recursive(text[length:], lengths, mapping)
            )
    return result


def decompose(text: str, mapping: dict[str, str]) -> list[str]:
    lengths = tuple(sorted({len(k) for k in mapping.keys()}, reverse=True))
    if lengths == (1,):
        return decompose_chars(text, mapping)
    return decompose_recursive(text, lengths, mapping)


def print_transformations(text: str, words: set[str] | None = None) -> None:
    if re.search(r"^\d+$", text):
        print(f"Decodings of {text!r}:")
        decodings = decompose(text, number_to_string)
        if words is not None:
            in_words = sorted(set.intersection(words, decodings))
            if in_words:
                print("  In dictionaries:")
                for decoding in in_words:
                    print("    " + decoding)
                    decodings.remove(decoding)
            if decodings:
                print("  Other:")
        for decoding in decodings:
            print("    " + decoding)
    elif re.search(r"^[a-z]+$", text):
        print(f"Encoding of {text!r}:")
        for encoding in decompose(text, string_to_number):
            print("    " + encoding)
    else:
        print(
            f"Input {text!r} is invalid; must be all digits or all lowercase letters."
        )


def load_words(inputs: list[Path]) -> set[str]:
    words: set[str] = set()
    for input in inputs:
        with open(input, "r", encoding="utf-8") as f:
            for line in f:
                words.add(re.sub(r"[^a-z]+", "", line.rstrip().lower()))
    return words


def main() -> None:
    files: list[Path] = []
    texts: list[str] = []
    unknowns: list[str] = []
    for arg in sys.argv[1:]:
        if Path(arg).is_file():
            files.append(Path(arg))
        elif re.search(r"^(?:\d+|[a-z]+)$", arg):
            texts.append(arg)
        else:
            unknowns.append(arg)
    if len(unknowns) > 0 or len(texts) < 1:
        print("Usage: letter_numbers.py [<word_file>...] <text> [<text>...]")
        print("  where <text> is either all digits, or all lowercase letters.")
        sys.exit(1)
    words = load_words(files) if files else None
    for text in texts:
        print_transformations(text, words=words)


if __name__ == "__main__":
    main()
