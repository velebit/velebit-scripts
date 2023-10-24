#!/not-executable/python3

# ===== operations on collections of collections =====

def flatten(collection_of_collections):
    return [element for collection in collection_of_collections
            for element in collection]


# ===== set operations over collections =====

def intersection(first, *rest):
    return frozenset(first).intersection(*(frozenset(s) for s in rest))


def difference(first, *rest):
    return frozenset(first).difference(*(frozenset(s) for s in rest))


def union(first, *rest):
    return frozenset(first).union(*(frozenset(s) for s in rest))


# ===== selection of elements from collections =====

def return_first_or_none(collection):
    "Inefficiently return the first collection element or None."
    return [*collection, None][0]


def select_all(collection, *conditions):
    return [i for i in collection if all([c(i) for c in conditions])]


def select_one(collection, *conditions):
    # return the first match or None
    return return_first_or_none(select_all(collection, *conditions))
