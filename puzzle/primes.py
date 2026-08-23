#!/usr/bin/env python3
"""Prime number generator and performance tester."""

from typing import Generator


def make_primes() -> Generator[int, None, None]:
    """Generator that produces prime numbers indefinitely."""
    yield 2
    candidates = 3
    while True:
        is_prime = True
        for i in range(3, int(candidates**0.5) + 1, 2):
            if candidates % i == 0:
                is_prime = False
                break
        if is_prime:
            yield candidates
        candidates += 2


def test_first_15_primes() -> None:
    """Get first 10 primes"""
    primes1 = make_primes()

    primes_list1: list[int] = []
    for i, prime in enumerate(primes1):
        primes_list1.append(prime)
        if i + 1 >= 10:
            break
    print(f"First 10 primes: {primes_list1}")
    assert primes_list1 == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]

    # Test continuing iteration from saved generator
    primes2 = iter(primes1)
    assert primes2 == primes1

    primes_list2: list[int] = []
    for i, prime in enumerate(primes2):
        primes_list2.append(prime)
        if i + 1 >= 5:
            break
    print(f"Next 5 primes: {primes_list2}")
    assert primes_list2 == [31, 37, 41, 43, 47]


def test_parallel() -> None:
    """Get first 10 primes from two generators"""
    primes1 = make_primes()
    primes2 = make_primes()

    actual_primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31]

    first_prime_1 = next(primes1)
    assert first_prime_1 == actual_primes[0]

    out_list: list[tuple[int, int]] = []
    for i, (p1, p2) in enumerate(zip(primes1, primes2)):
        out_list.append((p1, p2))
        if i + 1 >= 10:
            break
    expected = [
        (actual_primes[i + 1], actual_primes[i]) for i in range(len(actual_primes) - 1)
    ]
    assert out_list == expected


if __name__ == "__main__":
    test_first_15_primes()
    test_parallel()
