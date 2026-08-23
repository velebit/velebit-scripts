#!/usr/bin/env python3
"""Cached iterable implementation."""

from typing import Iterator, TypeVar, Generic

T = TypeVar("T")


class CachedIterable(Generic[T]):
    """A class that caches values from a (possibly infinite) iterator."""

    def __init__(self, iterator: Iterator[T]):
        self.input_iterator: Iterator[T] | None = iterator
        self.cache: list[T] = []

    def __iter__(self) -> Iterator[T]:
        index = 0
        while True:
            try:
                value = self._get_value(index)
            except StopIteration:
                return
            yield value
            index += 1

    def _get_value(self, index: int) -> T:
        """Get value at index, fetching from iterator if necessary."""
        if index < len(self.cache):
            return self.cache[index]
        elif self.input_iterator is None:
            raise StopIteration
        else:
            assert index == len(self.cache), "Index must be the next in sequence."
            try:
                value = next(self.input_iterator)
                self.cache.append(value)
                return value
            except StopIteration:
                self.input_iterator = None  # Mark the iterator as exhausted
                raise


def test_finite_cached_iterable() -> None:
    """Test CachedIterable with finite source"""
    finite_values = iter([10, 20, 30, 40])
    cached_finite = CachedIterable[int](finite_values)

    finite_pass1 = list(cached_finite)
    finite_pass2 = list(cached_finite)

    print(f"Finite pass 1: {finite_pass1}")
    print(f"Finite pass 2 (from cache): {finite_pass2}")
    assert finite_pass1 == [10, 20, 30, 40]
    assert finite_pass2 == finite_pass1


def test_infinite_cached_iterable() -> None:
    """Test CachedIterable with infinite source"""
    _infinite_data_counter = 0

    def make_infinite_data_for_test() -> Iterator[int]:
        """Yield an infinite sequence of integers starting at 0."""
        value = 0
        while True:
            nonlocal _infinite_data_counter
            _infinite_data_counter += 1
            yield value
            value += 1

    cached_numbers = CachedIterable[int](make_infinite_data_for_test())

    # Get first 10 numbers.
    # Don't use enumerate() here to avoid consuming the iterator too much.
    numbers_list: list[int] = []
    for number in cached_numbers:
        numbers_list.append(number)
        if len(numbers_list) >= 10:
            break
    print(f"First 10 numbers: {numbers_list}")
    assert numbers_list == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    # Test cache is working - iterate again
    numbers_list2: list[int] = []
    for number in cached_numbers:
        numbers_list2.append(number)
        if len(numbers_list2) >= 5:
            break
    print(f"First 5 numbers (from cache): {numbers_list2}")
    assert numbers_list2 == numbers_list[:5]

    # Test continuing iteration
    numbers_list3: list[int] = []
    for number in cached_numbers:
        numbers_list3.append(number)
        if len(numbers_list3) >= 15:
            break
    print(f"First 15 numbers (extended): {numbers_list3}")
    assert numbers_list3[:10] == numbers_list
    assert numbers_list3 == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
    assert _infinite_data_counter == 15, (
        "Should have generated 15 values from the infinite source,"
        f" generated {_infinite_data_counter}."
    )


if __name__ == "__main__":
    test_finite_cached_iterable()
    test_infinite_cached_iterable()
