#!/not-executable/python3
from collections.abc import Callable, Iterable, Hashable
from typing import TypeVar

_T = TypeVar("_T")
_H = TypeVar("_H", bound=Hashable)


# ===== operations on collections of collections =====

def flatten(collection_of_collections: Iterable[Iterable[_T]]) -> list[_T]:
    """Flatten an iterable of iterables into a single list."""
    return [element for collection in collection_of_collections
            for element in collection]


# ===== set operations over collections =====

def intersection(first: Iterable[_H], *rest: Iterable[_H]) -> frozenset[_H]:
    """Return the intersection of two or more iterables as a frozenset."""
    return frozenset(first).intersection(*(frozenset(s) for s in rest))


def difference(first: Iterable[_H], *rest: Iterable[_H]) -> frozenset[_H]:
    """Return elements in `first` that are not in any of the `rest` iterables, as a frozenset."""
    return frozenset(first).difference(*(frozenset(s) for s in rest))


def union(first: Iterable[_H], *rest: Iterable[_H]) -> frozenset[_H]:
    """Return the union of two or more iterables as a frozenset."""
    return frozenset(first).union(*(frozenset(s) for s in rest))


# ===== selection of elements from collections =====

def return_first_or_none(collection: Iterable[_T]) -> _T | None:
    "Return the first collection element or None."
    return next(iter(collection), None)


def select_as_iterator(
    collection: Iterable[_T], *conditions: Callable[[_T], bool]
) -> Iterable[_T]:
    """Return elements from `collection` that satisfy every condition, as an iterator."""
    return (i for i in collection if all(c(i) for c in conditions))


def select_all(
    collection: Iterable[_T], *conditions: Callable[[_T], bool]
) -> list[_T]:
    """Return all elements from `collection` that satisfy every condition, as a list."""
    return list(select_as_iterator(collection, *conditions))


def select_one(
    collection: Iterable[_T], *conditions: Callable[[_T], bool]
) -> _T | None:
    """Return the first element from `collection` that satisfies every condition, or None."""
    return return_first_or_none(select_as_iterator(collection, *conditions))
