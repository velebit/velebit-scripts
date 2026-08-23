#!/usr/bin/env python3
"""Plot the number of prime factors of integers."""

import argparse
from dataclasses import dataclass

import matplotlib.pyplot as plt

from cached_iterable import CachedIterable
from primes import make_primes

_primes_cache: CachedIterable[int] | None = None


def get_primes() -> CachedIterable[int]:
    """Return cached primes list, generating if necessary."""
    global _primes_cache
    if _primes_cache is None:
        _primes_cache = CachedIterable[int](make_primes())
    return _primes_cache


def prime_factors(n: int) -> dict[int, int]:
    """Return a dictionary of prime factors and their counts for n."""
    factors: dict[int, int] = {}
    for prime in get_primes():
        if prime * prime > n:
            break
        while n % prime == 0:
            factors[prime] = factors.get(prime, 0) + 1
            n //= prime
    if n > 1:
        factors[n] = factors.get(n, 0) + 1
    return factors


@dataclass(frozen=True)
class Factors:
    """Information about factors to plot."""

    limit: int
    indices: list[int]
    total_factors: list[int]
    unique_factors: list[int]
    average_count: list[float]
    inverse_count: list[float]


def calculate_factors(limit: int) -> Factors:
    """Plot the number of prime factors for integers up to limit."""
    indices = list(range(2, limit + 1))
    factors_list = [prime_factors(n) for n in indices]
    total_factors = [sum(pf.values()) for pf in factors_list]
    unique_factors = [len(pf) for pf in factors_list]
    average_count = [sum(pf.values()) / len(pf) for pf in factors_list]
    inverse_count = [1 / c for c in average_count]
    return Factors(
        limit=limit,
        indices=indices,
        total_factors=total_factors,
        unique_factors=unique_factors,
        average_count=average_count,
        inverse_count=inverse_count,
    )


def plot_prime_factors(data: Factors) -> None:
    """Plot the number of prime factors for integers up to limit."""
    plt.figure(figsize=(10, 5))
    plt.plot(
        data.indices, data.total_factors, "^", fillstyle="none", label="Total Factors"
    )
    plt.plot(
        data.indices, data.unique_factors, "v", fillstyle="none", label="Unique Factors"
    )
    plt.legend()
    plt.title(f"Number of Prime Factors for Integers up to {data.limit}")
    plt.xlabel("Integer")
    plt.ylabel("Number of Prime Factors")
    plt.grid()


def plot_prime_factors_xy(data: Factors) -> None:
    """Plot the number of prime factors for integers up to limit."""
    plt.figure(figsize=(10, 5))
    plt.plot(data.total_factors, data.unique_factors, "o", fillstyle="none")
    plt.title(f"Number of Prime Factors for Integers up to {data.limit}")
    plt.ylabel("Total Number of Prime Factors")
    plt.ylabel("Unique Number of Prime Factors")
    plt.grid()


def plot_average_prime_factor_count(data: Factors) -> None:
    """Plot the average number of instances of prime factors for integers up to limit."""
    plt.figure(figsize=(10, 5))
    plt.plot(data.indices, data.average_count, "x", label="Average Count Per Factor")
    plt.title(
        f"Average Number of Instances of Prime Factors for Integers up to {data.limit}"
    )
    plt.xlabel("Integer")
    plt.ylabel("Average Count of Prime Factors")
    plt.grid()

    plt.figure(figsize=(10, 5))
    plt.plot(data.indices, data.inverse_count, "+", label="Inverse of Average Count")
    plt.title(
        f"Inverse of Average Number of Instances of Prime Factors for Integers up to {data.limit}"
    )
    plt.xlabel("Integer")
    plt.ylabel("Inverse of Average Count of Prime Factors")
    plt.grid()


def main() -> None:
    """Script body"""
    parser = argparse.ArgumentParser(
        description="Plot the number of prime factors of integers."
    )
    parser.add_argument(
        "limit",
        type=int,
        help="The upper limit of integers to plot.",
        default=100,
        nargs="?",
    )
    args = parser.parse_args()

    data = calculate_factors(args.limit)
    plot_prime_factors(data)
    if False:
        plot_prime_factors_xy(data)
    if False:
        plot_average_prime_factor_count(data)
    plt.show()


if __name__ == "__main__":
    main()
