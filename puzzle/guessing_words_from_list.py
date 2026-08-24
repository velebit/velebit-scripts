#!/home/bert/.local/lib/python/venv/tasks/bin/python3

import argparse
from collections import Counter, defaultdict
from collections.abc import Sequence
from dataclasses import dataclass
from frozendict import frozendict
from functools import cache
import math


class UserInputError(ValueError):
    """Raised for invalid user-provided CLI arguments."""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Guessing words from list")
    parser.add_argument(
        "-a",
        "--all",
        action="store_true",
        default=False,
        help="Show all possible words",
    )
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
    return parser


def flatten_file_arguments(args: Sequence[str]) -> tuple[str, ...]:
    entries: list[str] = []
    for arg in args:
        if arg.startswith("@"):
            filename = arg[1:]
            print(f"Reading words from file: {filename}")
            try:
                with open(filename, "r") as f:
                    for line in f:  # non-recursively
                        xarg = line.strip()
                        if not xarg:
                            continue
                        if xarg in entries:
                            raise UserInputError(f'Word is repeated: "{xarg}"')
                        entries.append(xarg)
            except (
                FileNotFoundError,
                IsADirectoryError,
                PermissionError,
            ) as e:
                raise UserInputError(f"Could not open file '{filename}': {e}") from e
        else:
            if arg in entries:
                raise UserInputError(f'Word is repeated: "{arg}"')
            entries.append(arg)
    return tuple(entries)


def parse_word_arguments(
    word_args: Sequence[str],
) -> tuple[tuple[str, ...], frozendict[str, int]]:
    word_args = flatten_file_arguments(word_args)
    open_words: list[str] = []
    guessed_words: dict[str, int] = {}
    for word in word_args:
        if "=" in word:
            if word.count("=") != 1:
                raise UserInputError(
                    f'Invalid guessed-word entry "{word}": expected exactly one "="'
                )
            guessed_word, str_matches = word.split("=", 1)
            if not guessed_word:
                raise UserInputError(
                    f'Invalid guessed-word entry "{word}": missing word before "="'
                )
            try:
                matches = int(str_matches)
            except ValueError as e:
                raise UserInputError(
                    f'Invalid guessed-word entry "{word}": number of matches must be an integer'
                ) from e
            if str(matches) != str_matches:
                raise UserInputError(
                    f'Invalid guessed-word entry "{word}": number of matches must be an integer'
                )
            if matches < 0:
                raise UserInputError(
                    f'Invalid guessed-word entry "{word}": number of matches must be non-negative'
                )
            if matches >= len(guessed_word):
                raise UserInputError(
                    f'Invalid guessed-word entry "{word}": number of matches must be less than the word length ({len(guessed_word)})'
                )
            if guessed_word in open_words or guessed_word in guessed_words:
                raise UserInputError(f'Word is repeated: "{guessed_word}"')
            guessed_words[guessed_word] = matches
        else:
            if word in open_words or word in guessed_words:
                raise UserInputError(f'Word is repeated: "{word}"')
            open_words.append(word)
    if len(open_words) == 0:
        raise UserInputError("Some not-yet-guessed words must be specified")
    all_words = (*open_words, *guessed_words.keys())
    word_lengths = set(len(word) for word in all_words)
    if len(word_lengths) != 1:
        length_map = {wl: [w for w in all_words if len(w) == wl] for wl in word_lengths}
        raise UserInputError(f"All words must have the same length ({length_map})")
    return (tuple(open_words), frozendict(guessed_words))


@cache
def get_matches(word0: str, word1: str) -> int:
    """Return the number of matching letters in the same position between two words."""
    return sum(1 for a, b in zip(word0, word1) if a == b)


# Note: `words` and `guesses` must be Hashable types, to support @cache
@cache
def get_possible_words(
    words: tuple[str, ...], guesses: frozendict[str, int]
) -> tuple[str, ...]:
    """Return the list of possible words that match the given guesses."""
    possible_words: list[str] = []
    for word in words:
        if all(
            get_matches(word, guess) == matches for guess, matches in guesses.items()
        ):
            possible_words.append(word)
    return tuple(possible_words)


@cache
def get_total_unknown_bits(words: tuple[str, ...]) -> float:
    assert len(words) > 0
    return math.log2(len(words))


@dataclass(frozen=True)
class RangeInfo:
    """Information about the range of bits after a guess."""

    expected: float
    min: float
    max: float


@dataclass(frozen=True)
class GuessEntropyBits:
    """Information about the expected entropy decrease for a guess."""

    total_unknown_bits_before: float
    remaining_bits: RangeInfo
    information_decrease: RangeInfo


@cache
def get_entropy_data_for_choice(
    *, words: tuple[str, ...], choice: str
) -> GuessEntropyBits:
    assert len(words) > 0
    num_words_with_this_many_matches = Counter[int](
        get_matches(choice, actual) for actual in words
    )
    word_group_sizes = tuple(num_words_with_this_many_matches.values())
    total = len(words)
    assert sum(word_group_sizes) == total, "Group sizes must sum to total words"

    # this is the weighted average of the log2(count), weighted by the probability of each value
    expected_remaining_bits = sum(
        (count / total) * math.log2(count) for count in word_group_sizes
    )
    min_remaining_bits = math.log2(min(word_group_sizes))
    max_remaining_bits = math.log2(max(word_group_sizes))

    total_unknown_bits_before = math.log2(total)
    assert (
        get_total_unknown_bits(words) == total_unknown_bits_before
    ), "Total unknown bits must match"

    # This is the same as the feedback entropy for this guess,
    #   -sum((count / total) * log2(count / total)) for count in word_group_sizes)
    expected_information_decrease = total_unknown_bits_before - expected_remaining_bits
    min_information_decrease = total_unknown_bits_before - max_remaining_bits
    max_information_decrease = total_unknown_bits_before - min_remaining_bits

    return GuessEntropyBits(
        total_unknown_bits_before=total_unknown_bits_before,
        remaining_bits=RangeInfo(
            expected=expected_remaining_bits,
            min=min_remaining_bits,
            max=max_remaining_bits,
        ),
        information_decrease=RangeInfo(
            expected=expected_information_decrease,
            min=min_information_decrease,
            max=max_information_decrease,
        ),
    )


# Note: `words` and `guesses` must be Hashable types, to support @cache
@cache
def get_all_max_guesses(
    *, words: tuple[str, ...], guesses: frozendict[str, int]
) -> frozendict[int, tuple[str, ...]]:
    assert len(words) > 0
    if len(words) == 1:
        return frozendict({1: tuple(words)})
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
            assert next_words, "There must be at least one possible word after a guess"
            next_max_guesses = get_all_max_guesses(
                words=next_words, guesses=next_guesses
            )
            # assume optimal strategy: 1 (this guess) plus the minimum number of max guesses across next choices
            num_guesses = 1 + min(next_max_guesses.keys())
            max_guesses_for_choice = max(max_guesses_for_choice, num_guesses)
        max_guesses_by_choice[choice] = max_guesses_for_choice
    choice_by_max_guesses: dict[int, tuple[str, ...]] = {}
    for max_guesses in set(max_guesses_by_choice.values()):
        choices = tuple(k for k, v in max_guesses_by_choice.items() if v == max_guesses)
        choice_by_max_guesses[max_guesses] = choices
    return frozendict(choice_by_max_guesses)


def print_best_words_info(
    entropy_data: dict[str, GuessEntropyBits],
    max_guesses: int,
    best_words: tuple[str, ...],
) -> None:
    """Print information about the best words."""
    for word in best_words:
        print(
            f"  {word}: {max_guesses} max guesses\n"
            "    expected entropy decrease is"
            f" {entropy_data[word].information_decrease.expected:.2f} bits"
            f" ({entropy_data[word].information_decrease.min:.2f}"
            f"-{entropy_data[word].information_decrease.max:.2f}),"
            f" remaining: {entropy_data[word].remaining_bits.expected:.2f} bits"
            f" ({entropy_data[word].remaining_bits.min:.2f}"
            f"-{entropy_data[word].remaining_bits.max:.2f})"
        )


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    try:
        words, guesses = parse_word_arguments(args.words)
        if guesses:
            print(
                f"{len(words)+len(guesses)} words specified,"
                f" {len(guesses)} already guessed."
            )
        else:
            print(f"{len(words)} words specified.")

        possible_words = get_possible_words(words, guesses)
        if not possible_words:
            raise UserInputError(
                "No possible words remain: the provided guesses are inconsistent with the word list"
            )
        total_bits = get_total_unknown_bits(possible_words)
        print(f"Current unknown information: {total_bits:.3f} bits")

        words_by_max_guesses = get_all_max_guesses(
            words=possible_words, guesses=guesses
        )
        entropy_data = {
            choice: get_entropy_data_for_choice(words=possible_words, choice=choice)
            for choice in possible_words
        }
        ordered_words_by_max_guesses: dict[int, tuple[str, ...]] = {}
        for max_guesses, best_words in words_by_max_guesses.items():
            best_words = tuple(sorted(best_words))  # break ties
            best_words = tuple(
                sorted(
                    best_words,
                    key=lambda w: entropy_data[w].information_decrease.expected,
                    reverse=True,
                )
            )
            ordered_words_by_max_guesses[max_guesses] = best_words

        max_guesses = min(ordered_words_by_max_guesses.keys())
        best_words = ordered_words_by_max_guesses[max_guesses]
        print(f"Best words:")
        print_best_words_info(entropy_data, max_guesses, best_words)

        if args.all:
            other_max_guesses = sorted(
                k for k in ordered_words_by_max_guesses.keys() if k != max_guesses
            )
            if other_max_guesses:
                print("\nOther words:")
            for max_guesses in other_max_guesses:
                best_words = ordered_words_by_max_guesses[max_guesses]
                print_best_words_info(entropy_data, max_guesses, best_words)

    except UserInputError as e:
        parser.error(str(e))


if __name__ == "__main__":
    main()
