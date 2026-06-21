#!/home/bert/.local/lib/python/venv/tasks/bin/ipython3

import argparse
from collections.abc import Collection, Hashable, Mapping, Sequence
from frozendict import frozendict
from functools import cache


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Guessing words from list")
    parser.add_argument(
        "words",
        type=str,
        nargs="+",
        help=(
            "The list of words to guess from."
            ' For already attempted guesses, use "GUESSED_WORD=NUM_MATCHES".'
            " @FILE reads entries from a file."
        ),
    )
    return parser.parse_args()


def flatten_file_arguments(args: Sequence[str]) -> tuple[str, ...]:
    entries: list[str] = []
    for arg in args:
        if arg.startswith("@"):
            filename = arg[1:]
            with open(filename, "r") as f:
                for line in f:  # non-recursively
                    xarg = line.strip()
                    assert xarg not in entries, "Words should not be repeated"
                    entries.append(xarg)
        else:
            assert arg not in entries, "Words should not be repeated"
            entries.append(arg)
    return tuple(entries)


def parse_word_arguments(
    word_args: Sequence[str],
) -> tuple[tuple[str, ...], frozendict[str, int]]:
    word_args = flatten_file_arguments(word_args)
    open_words: list[str] = []
    guessed_words: dict[str, int] = {}
    for word in word_args:
        try:
            guessed_word, str_matches = word.split("=")
            matches = int(str_matches)
            assert str(matches) == str_matches, "Number of matches must be an integer"
            assert matches >= 0, "Number of matches must be non-negative"
            assert matches < len(
                guessed_word
            ), "Number of matches must be less than the length of the word"
            assert (
                guessed_word not in open_words
                and guessed_word not in guessed_words.keys()
            ), "Words should not be repeated"
            guessed_words[guessed_word] = matches
        except ValueError:
            assert (
                word not in open_words and word not in guessed_words.keys()
            ), "Words should not be repeated"
            open_words.append(word)
    assert len(open_words) > 0, "Some not yet guessed words should be specified"
    assert all(
        len(word) == len(open_words[0]) for word in (*open_words, *guessed_words.keys())
    ), "All words must have the same length"
    return (tuple(open_words), frozendict(guessed_words))


@cache
def get_matches(word0: str, word1: str) -> int:
    return sum(1 for a, b in zip(word0, word1) if a == b)


# Note: `words` and `guesses` must be Hashable types, to support @cache
@cache
def get_possible_words(
    words: tuple[str, ...], guesses: frozendict[str, int]
) -> tuple[str, ...]:
    possible_words: list[str] = []
    for word in words:
        if all(
            get_matches(word, guess) == matches for guess, matches in guesses.items()
        ):
            possible_words.append(word)
    return tuple(possible_words)


# Note: `words` and `guesses` must be Hashable types, to support @cache
@cache
def get_best_max_guesses(
    *, words: tuple[str, ...], guesses: frozendict[str, int]
) -> tuple[int, tuple[str, ...]]:
    assert len(words) > 0
    if len(words) == 1:
        return (1, tuple(words))
    max_guesses_by_choice: dict[str, int] = {}
    for choice in words:
        max_guesses_for_choice = 1
        for actual in words:
            if choice == actual:
                continue
            next_guesses: frozendict[str, int] = frozendict(
                {**guesses, choice: get_matches(choice, actual)}
            )
            next_words = get_possible_words(words, next_guesses)
            num_guesses = (
                1 + get_best_max_guesses(words=next_words, guesses=next_guesses)[0]
            )
            max_guesses_for_choice = max(max_guesses_for_choice, num_guesses)
        max_guesses_by_choice[choice] = max_guesses_for_choice
    best_max = min(max_guesses_by_choice.values())
    best_choices = tuple(k for k, v in max_guesses_by_choice.items() if v == best_max)
    return (best_max, best_choices)


def main() -> None:
    args = parse_arguments()
    words, guesses = parse_word_arguments(args.words)
    print(f"{len(words)+len(guesses)} words specified.")

    possible_words = get_possible_words(words, guesses)
    max_guesses, best_words = get_best_max_guesses(
        words=possible_words, guesses=guesses
    )
    print(f"Best words (max {max_guesses} guesses):")
    for word in best_words:
        print(f"  {word}")


if __name__ == "__main__":
    main()
