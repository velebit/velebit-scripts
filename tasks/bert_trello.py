#!/not-executable/python3
from collections.abc import Callable, Collection, Iterable
from dataclasses import dataclass
import dateutil
import dateutil.parser
import json
import os
import sys
import trello  # type: ignore[import-untyped]
from trello import TrelloClient, Board, Card, Label  # type: ignore[import-untyped]
from trello.trellolist import List  # type: ignore[import-untyped]
from typing import Any, cast

from bert_task_utilities import flatten, difference, union, intersection, select_one

# ===== data types =====


@dataclass
class CardInfo:
    "Information about a Trello card"

    name: str
    desc: str | None = None
    cards: list[Card] = []


# A label-rule dict mapping rule-key constants to sets of label objects
_LabelRule = dict[str, Collection[Label]]


# ===== constants =====

# keys for label manipulation
ADD_LABELS = "add"
REMOVE_LABELS = "rm"
RETIRE_LABELS = "retire"
IF_PRESENT_ANY_LABELS = "if+any"
IF_MISSING_ALL_LABELS = "if-all"


# ===== authentication and client object management =====


def get_auth_file_name() -> str:
    home_dir = os.getenv("HOME")
    assert home_dir is not None, "HOME needs to be set"
    return home_dir + "/.config/bert_trello/auth.json"


def read_auth_data() -> dict[str, str]:
    with open(get_auth_file_name(), "r", encoding="utf-8") as f:
        auth = json.load(f)
    assert "api_key" in auth
    assert "api_secret" in auth
    return auth


def create_auth_token(
    auth: dict[str, str], save_if_updated: bool = True
) -> dict[str, str]:
    token: Any = trello.create_oauth_token(  # type: ignore[attr-defined]
        key=auth["api_key"], secret=auth["api_secret"]
    )
    assert isinstance(token, dict)
    token = cast(dict[str, str], token)
    assert all(isinstance(k, str) and isinstance(v, str) for k, v in token.items())
    for k in token:
        auth[k] = token[k]
    if save_if_updated:
        with open(get_auth_file_name(), "w", encoding="utf-8") as f:
            json.dump(auth, f)
    assert "oauth_token" in auth
    assert "oauth_token_secret" in auth
    return auth


def get_full_auth_data(
    auth: dict[str, str] | None = None,
    allow_update: bool = True,
    save_if_updated: bool = True,
) -> dict[str, str]:
    if auth is None:
        auth = read_auth_data()
    if "oauth_token" not in auth or "oauth_token_secret" not in auth:
        if allow_update:
            auth = create_auth_token(auth, save_if_updated)
        else:
            assert False, (
                "Refusing to create auth token since stdin may be"
                + "piped; try e.g. trello_boards?"
            )
            # If assertion fails, other apps will create a token we can use!
    return auth


def create_client(auth: dict[str, str] | None = None) -> TrelloClient:
    if auth is None:
        auth = get_full_auth_data()
    client = TrelloClient(
        api_key=auth["api_key"],
        api_secret=auth["api_secret"],
        token=auth["oauth_token"],
        token_secret=auth["oauth_token_secret"],
    )
    return client


# ===== creating and applying selector condition functions =====

# Consider limiting these to specific Trello objects.


def item_id_is(item_id: str) -> Callable[[Any], bool]:
    return lambda i: i.id == item_id


def item_name_is(item_name: str) -> Callable[[Any], bool]:
    return lambda i: i.name == item_name


def item_is_open() -> Callable[[Any], bool]:
    return lambda i: not i.closed


# ===== accessing existing boards, labels and lists =====


def get_open_board_by_id(client: TrelloClient, id: str) -> Board | None:
    return select_one(client.list_boards(), item_is_open(), item_id_is(id))


def get_open_board_by_name(client: TrelloClient, name: str) -> Board | None:
    return select_one(client.list_boards(), item_is_open(), item_name_is(name))


def get_multiple_labels_by_name(
    board: Board, names: Iterable[str]
) -> dict[str, Label | None]:
    all_labels = board.get_labels()
    return {n: select_one(all_labels, item_name_is(n)) for n in names}


def get_any_list_by_id(board: Board, id: str) -> List:
    tlist = List(board, id)
    tlist.fetch()
    return tlist


def get_any_list_by_name(board: Board, name: str) -> List | None:
    return select_one(board.list_lists(), item_name_is(name))


def get_open_list_by_id(board: Board, id: str) -> List | None:
    tlist = get_any_list_by_id(board, id)
    if tlist.closed:  # type: ignore[attr-defined]
        return None
    return tlist


def get_open_list_by_name(board: Board, name: str) -> List | None:
    return select_one(board.open_lists(), item_name_is(name))


# ===== getting a board handle, with authentication setup and logging =====


def get_board(
    board_id: str,
    board_name: str,
    auth: dict[str, str] | None = None,
    verbosity: int = 0,
) -> Board:
    verbosity_threshold, extra_msg = 2, ""
    client = create_client(auth=auth)
    board = get_open_board_by_id(client, board_id)
    if board is None:
        board = get_open_board_by_name(client, board_name)
        if board_name != board_id:
            verbosity_threshold, extra_msg = 1, "*by name*, fix the ID!"
    assert board is not None, "No open board found"
    if verbosity >= verbosity_threshold:
        actual_board_name = board.name  # type: ignore[assignment]
        actual_board_id = board.id  # type: ignore[assignment]
        print(
            f"(T) Selected board '{actual_board_name}' ({actual_board_id}){extra_msg}",
            file=sys.stderr,
        )
    return board


# ===== creating labels =====


def get_or_create_labels(
    board: Board, names: Iterable[str], verbosity: int = 0
) -> Iterable[Label]:
    label_map = get_multiple_labels_by_name(board, names)
    for label in tuple(label_map.keys()):
        if label_map[label] is not None:
            if verbosity >= 2:
                label_obj = label_map[label]
                assert label_obj is not None  # checked above but mypy doesn't see that
                label_name: str = label_obj.name  # type: ignore[assignment]
                label_id: str = label_obj.id  # type: ignore[assignment]
                print(
                    f"(T) Selected label '{label_name}' ({label_id})", file=sys.stderr
                )
        else:
            label_map[label] = board.add_label(label, "black")  # type: ignore[assignment]
            assert label_map[label] is not None
            if verbosity >= 2:
                label_obj = label_map[label]
                assert label_obj is not None  # checked above but mypy doesn't see that
                label_name = label_obj.name  # type: ignore[assignment]
                label_id = label_obj.id  # type: ignore[assignment]
                print(
                    f"(T) Created label  '{label_name}' ({label_id})", file=sys.stderr
                )
    labels = label_map.values()
    assert all(l is not None for l in labels)
    return [l for l in labels if l is not None]


# ===== creating lists =====


def get_list(
    board: Board, list_id: str | None, list_name: str | None, verbosity: int = 0
) -> List | None:
    verbosity_threshold, extra_msg = 1, ""
    tlist = None
    if list_id is not None:
        tlist = get_any_list_by_id(board, list_id)
    if tlist is None and list_name is not None:
        tlist = get_any_list_by_name(board, list_name)
        if list_id is not None:
            verbosity_threshold, extra_msg = 0, "*by name*, fix the ID!"
    if tlist is not None:
        if verbosity >= verbosity_threshold:
            tlist_name = tlist.name  # type: ignore[assignment]
            tlist_id = tlist.id  # type: ignore[assignment]
            print(
                f"(T) Selected list  '{tlist_name}' ({tlist_id}){extra_msg}",
                file=sys.stderr,
            )
    return tlist


def get_or_create_list(
    board: Board, list_id: str | None, list_name: str | None, verbosity: int = 0
) -> List:
    tlist = get_list(board, list_id, list_name, verbosity)
    if tlist is None:
        tlist = board.add_list(list_name, pos="top")  # type: ignore[attr-defined]
        assert tlist is not None, "List creation returned None"
        if verbosity >= 0:
            tlist_name = tlist.name  # type: ignore[assignment]
            tlist_id = tlist.id  # type: ignore[assignment]
            print(f"(T) Created list  '{tlist_name}' ({tlist_id})", file=sys.stderr)
    assert tlist is not None, "No list found or created"
    return tlist


def reopen_list(tlist: List, *, verbosity: int = 0, dry_run: bool = False) -> None:
    if tlist.closed:  # type: ignore[attr-defined]
        if dry_run:
            if verbosity >= 0:
                tlist_name = tlist.name  # type: ignore[assignment]
                tlist_id = tlist.id  # type: ignore[assignment]
                print(
                    f"(T) Did not reopen list '{tlist_name}' ({tlist_id})",
                    file=sys.stderr,
                )
        else:
            tlist.open()
            if verbosity >= 0:
                tlist_name = tlist.name  # type: ignore[assignment]
                tlist_id = tlist.id  # type: ignore[assignment]
                print(f"(T) Reopened list '{tlist_name}' ({tlist_id})", file=sys.stderr)


# ===== creating cards =====


def is_card_template(card: Card) -> bool:
    # HACK: this accesses internal JSON data and may not be generally reliable.
    #   But it will work fine for cards retrieved via board.open_cards(), since
    #   the internal JSON data will be populated in that case.
    json = card._json_obj  # pyright: ignore[reportPrivateUsage]
    assert json is not None
    if "cover" in json:
        if "isTemplate" in json["cover"]:
            return json["cover"]["isTemplate"]  # what the API docs specify
    if "isTemplate" in json:
        return json["isTemplate"]  # what the API actually currently returns
    return False


def get_cards_with_info(
    board: Board, cards: Collection[CardInfo], /, include_templates: bool = True
) -> list[CardInfo]:
    existing: dict[str, list[Card]] = {}
    for c in board.open_cards():
        if include_templates or not is_card_template(c):
            card_name: str = cast(str, c.name)  # type: ignore[assignment]
            existing.setdefault(card_name, []).append(c)
    cards = [type(info)(**info.__dict__) for info in cards]  # clone the info list
    for info in cards:
        info.cards = existing.get(info.name, [])
    return cards


def log_existing_cards(
    cards: list[CardInfo],
    /,
    verbosity: int = 0,
    separate_templates: bool = True,
    ignore_duplicates_in_lists: dict[str, Collection[str]] = {},
) -> None:
    if verbosity < 0:
        return  # verbosity 0 required to log
    for info in cards:
        if len(info.cards) == 1 and verbosity < 1:
            continue  # at verbosity 0 need >1 total card, don't bother checking more
        group_parts: list[str] = []
        need_to_log = False
        card_objs = list(info.cards)
        if separate_templates:
            template_cards = [c for c in card_objs if is_card_template(c)]
            card_objs = [
                c for c in card_objs if c not in template_cards
            ]  # remove from card_objs
            group_parts.insert(0, f"{len(template_cards)} template")
            if len(template_cards) > 1:
                need_to_log = True
        if ignore_duplicates_in_lists:
            cards_with_list_id = [(c, cast(str, c.list_id)) for c in card_objs]
            ignored_parts: list[str] = []
            for ignore_name, ignore_list_ids in ignore_duplicates_in_lists.items():
                ignored = [
                    c_id for c_id in cards_with_list_id if c_id[1] in ignore_list_ids
                ]
                cards_with_list_id = [
                    c_id for c_id in cards_with_list_id if c_id not in ignored
                ]  # remove from cards_with_list_id
                ignored_parts.append(f"{len(ignored)} {ignore_name}")
            # prepend ignored_parts to group_parts
            for part in reversed(ignored_parts):
                group_parts.insert(0, part)
            # never update need_to_log for ignored cards
            card_objs = [c for c, _ in cards_with_list_id]
        if len(group_parts) == 0:
            # if everything is together, don't bother labeling
            group_parts.insert(0, str(len(card_objs)))
            saw_one_single_card = len(card_objs) == 1
        else:
            group_parts.insert(0, f"{len(card_objs)} active")
            saw_one_single_card = False
        if len(card_objs) > 1:
            need_to_log = True
        if need_to_log or verbosity >= 1:
            all_counts = " + ".join(group_parts)
            if saw_one_single_card:
                print(
                    f"(T) {all_counts} card matching {info.name!r}" " already exists!",
                    file=sys.stderr,
                )
            else:
                print(
                    f"(T) {all_counts} cards matching {info.name!r}" " already exist!",
                    file=sys.stderr,
                )


def create_cards_with_info(
    tlist: List,
    cards: Collection[CardInfo],
    labels: Collection[Label] | None = None,
    verbosity: int = 0,
) -> Collection[CardInfo]:
    for info in cards:
        reopen_list(tlist, verbosity=verbosity)
        card = tlist.add_card(  # type: ignore[attr-exists]
            info.name, desc=info.desc, labels=labels
        )
        if verbosity >= 0:
            card_name = card.name  # type: ignore[assignment]
            print(f"(T) Card '{card_name}' created.", file=sys.stderr)
        info.cards.append(card)
    return cards


def get_or_create_cards_with_info(
    tlist: List,
    cards_in: Collection[CardInfo],
    labels: Collection[Label] | None = None,
    /,
    verbosity: int = 0,
    log_templates_separately: bool = True,
    log_ignore_duplicates_in_lists: dict[str, Collection[str]] = {},
) -> list[CardInfo]:
    board: Board = tlist.board  # type: ignore[assignment]
    assert isinstance(board, Board)
    cards = get_cards_with_info(board, cards_in)
    log_existing_cards(
        cards,
        verbosity=verbosity,
        separate_templates=log_templates_separately,
        ignore_duplicates_in_lists=log_ignore_duplicates_in_lists,
    )
    missing = [c for c in cards if len(c.cards) == 0]
    if len(missing) > 0:
        # Note: will update `cards` by updating members of `missing`!
        create_cards_with_info(tlist, missing, labels=labels, verbosity=verbosity)
    return cards


def grouped_cards_from_info(infos: list[CardInfo]) -> list[list[Card]]:
    return [list(c.cards) for c in infos]


def cards_from_info(infos: list[CardInfo]) -> list[Card]:
    return flatten(grouped_cards_from_info(infos))


def get_or_create_cards(
    tlist: List,
    cards: list[CardInfo],
    labels: list[Label] | None = None,
    verbosity: int = 0,
) -> list[Card]:
    return cards_from_info(
        get_or_create_cards_with_info(tlist, cards, labels, verbosity)
    )


# ===== moving cards between lists =====


def move_cards_to_list(
    cards: Iterable[Card], dst_list: List, *, verbosity: int = 0, dry_run: bool = False
) -> None:
    for c in cards:
        prev_list = c.get_list()
        reopen_list(dst_list, verbosity=verbosity, dry_run=dry_run)
        if dry_run:
            if verbosity >= 0:
                card_name = c.name  # type: ignore[assignment]
                src = prev_list.name  # type: ignore[assignment]
                dst = dst_list.name  # type: ignore[assignment]
                print(
                    f"(T) Did not move card '{card_name}' from '{src}' to '{dst}'.",
                    file=sys.stderr,
                )
        else:
            c.change_list(dst_list.id)  # type: ignore[attr-exists]
            if verbosity >= 0:
                card_name = c.name  # type: ignore[assignment]
                src = prev_list.name  # type: ignore[assignment]
                dst = dst_list.name  # type: ignore[assignment]
                print(
                    f"(T) Moved card '{card_name}' from '{src}' to '{dst}'.",
                    file=sys.stderr,
                )


def move_cards_from_lists_to_list(
    cards: Iterable[Card],
    src_lists: Collection[List],
    dst_list: List,
    *,
    verbosity: int = 0,
    dry_run: bool = False,
) -> None:
    moving = [(c, (c.get_list() in src_lists)) for c in cards]
    if verbosity >= 3:
        for card in (m[0] for m in moving if not m[1]):
            card_name = card.name  # type: ignore[assignment]
            list_name = card.get_list().name  # type: ignore[assignment]
            print(
                f"(T) Card '{card_name}' is in list {list_name}, not in filter lists",
                file=sys.stderr,
            )
    move_cards_to_list(
        (m[0] for m in moving if m[1]), dst_list, verbosity=verbosity, dry_run=dry_run
    )


def move_cards_not_in_lists_to_list(
    cards: Iterable[Card],
    excl_lists: Collection[List],
    dst_list: List,
    *,
    verbosity: int = 0,
    dry_run: bool = False,
) -> None:
    moving = [(c, (c.get_list() not in excl_lists)) for c in cards]
    if verbosity >= 3:
        for card in (m[0] for m in moving if not m[1]):
            card_name = card.name  # type: ignore[assignment]
            list_name = card.get_list().name  # type: ignore[assignment]
            print(
                f"(T) Card '{card_name}' is in list {list_name}, in exclude lists",
                file=sys.stderr,
            )
    move_cards_to_list(
        (m[0] for m in moving if m[1]), dst_list, verbosity=verbosity, dry_run=dry_run
    )


# ===== directly managing labels on a card =====


def add_labels_to_card(
    card: Card, labels_to_add: Iterable[Label], verbosity: int = 0
) -> bool:
    missing_labels = difference(labels_to_add, card.labels)
    if len(missing_labels) > 0:
        for ml in missing_labels:
            card.add_label(ml)  # type: ignore[attr-exists]
        if verbosity >= 0:
            card_name = card.name  # type: ignore[attr-exists]
            label_info = ", ".join(
                [
                    "'" + ml.name + "'"  # type: ignore[attr-exists]
                    for ml in missing_labels
                ]
            )
            print(
                f"(T) Updated card '{card_name}': added label(s) {label_info}.",
                file=sys.stderr,
            )
        return True
    else:
        return False


def remove_labels_from_card(
    card: Card, labels_to_remove: Iterable[Label], verbosity: int = 0
) -> bool:
    extra_labels = intersection(labels_to_remove, card.labels)
    if len(extra_labels) > 0:
        for el in extra_labels:
            card.remove_label(el)  # type: ignore[attr-exists]
        if verbosity >= 0:
            card_name = card.name  # type: ignore[attr-exists]
            label_info = ", ".join(
                [
                    "'" + el.name + "'"  # type: ignore[attr-exists]
                    for el in extra_labels
                ]
            )
            print(
                f"(T) Updated card '{card_name}': removed label(s) {label_info}.",
                file=sys.stderr,
            )
        return True
    else:
        return False


# ===== managing labels on cards according to rules =====


def look_up_label_objects_in_label_rules(
    board: Board, label_str_rules: list[dict[str, list[str]]], verbosity: int = 0
) -> list[_LabelRule]:
    return [
        {
            k: frozenset(get_or_create_labels(board, v, verbosity=verbosity))
            for k, v in lsr.items()
        }
        for lsr in label_str_rules
    ]


def get_default_labels_from_rules(
    label_rules: Collection[_LabelRule],
) -> frozenset[Label]:
    return frozenset(
        flatten(
            (
                lr[ADD_LABELS]
                for lr in label_rules
                if ADD_LABELS in lr and IF_PRESENT_ANY_LABELS not in lr
            )
        )
    )


def update_card_labels(
    cards: Iterable[Card], label_rules: Collection[_LabelRule], verbosity: int = 0
) -> None:
    for card in cards:
        want_labels = frozenset(card.labels)
        for rule in label_rules:
            # sanity check: if both ADD and REMOVE, there should be no overlap
            if ADD_LABELS in rule and REMOVE_LABELS in rule:
                add_and_remove = intersection(rule[ADD_LABELS], rule[REMOVE_LABELS])
                assert (
                    len(add_and_remove) == 0
                ), f"Labels are being added AND removed: {add_and_remove}"
            # sanity check: if multiple IFs, there should be no overlap
            if IF_PRESENT_ANY_LABELS in rule and IF_MISSING_ALL_LABELS in rule:
                present_and_missing = intersection(
                    rule[IF_PRESENT_ANY_LABELS], rule[IF_MISSING_ALL_LABELS]
                )
                assert len(present_and_missing) == 0, (
                    "Checking for labels to be present AND missing:"
                    f" {present_and_missing}"
                )
            # apply the rules
            if IF_PRESENT_ANY_LABELS in rule:
                present_labels = intersection(want_labels, rule[IF_PRESENT_ANY_LABELS])
                if len(present_labels) == 0:
                    continue  # rule's condition was not met
            if IF_MISSING_ALL_LABELS in rule:
                missing_labels = intersection(want_labels, rule[IF_MISSING_ALL_LABELS])
                if len(missing_labels) > 0:
                    continue  # rule's condition was not met
            if ADD_LABELS in rule:
                want_labels = union(want_labels, rule[ADD_LABELS])
            if REMOVE_LABELS in rule:
                want_labels = difference(want_labels, rule[REMOVE_LABELS])
        add_labels_to_card(
            card, difference(want_labels, card.labels), verbosity=verbosity
        )
        remove_labels_from_card(
            card, difference(card.labels, want_labels), verbosity=verbosity
        )
        # The assertion is unreliable because the card.labels update is delayed


#        assert frozenset(card.labels) == want_labels


def update_orphan_labeled_tasks(
    board: Board,
    label_rules: Collection[_LabelRule],
    tasks: Collection[CardInfo],
    verbosity: int = 0,
) -> None:
    task_names = [t.name for t in tasks]
    cards_not_in_tasks_list = [
        c
        for c in board.open_cards()
        if c.name not in task_names  # type: ignore[attr-exists]
    ]
    for card in cards_not_in_tasks_list:
        want_labels = frozenset(card.labels)
        for rule in label_rules:
            # Only look at rules that have RETIRE and either ADD or REMOVE
            # specified. For those rules, if either -ADD or -REMOVE removes
            # anything, also do +RETIRE.
            if RETIRE_LABELS not in rule:
                continue
            try_remove: list[Label] = []
            if ADD_LABELS in rule:
                try_remove.extend(rule[ADD_LABELS])
            if REMOVE_LABELS in rule:
                try_remove.extend(rule[REMOVE_LABELS])
            if len(try_remove):
                extra = intersection(card.labels, try_remove)
                if len(extra) > 0:
                    want_labels = difference(want_labels, try_remove)
                    want_labels = union(want_labels, rule[RETIRE_LABELS])
        add_labels_to_card(
            card, difference(want_labels, card.labels), verbosity=verbosity
        )
        remove_labels_from_card(
            card, difference(card.labels, want_labels), verbosity=verbosity
        )
        # The assertion is unreliable because the card.labels update is delayed


#        assert frozenset(card.labels) == want_labels


# ===== formatting and printing card information in a uniform way =====


def format_cards(
    cards: Iterable[Card],
    *,
    key: Callable[[Card], Any] | None = None,
    show_index: bool = False,
    show_template: bool = False,
    show_created: bool = True,
    show_updated: bool = True,
    show_list: bool = True,
    show_id: bool = False,
    show_start: bool = False,
    show_due: bool = False,
    newline_before_start_due: bool = True,
    show_url: bool = True,
    newline_before_url: bool = True,
    timezone: Any = None,
) -> tuple[list[str], list[Card]]:
    if key is None:

        def _key(c: Card) -> Any:
            return c.created_date

        key = _key
    card_info: list[list[Any]] = []
    for i, c in enumerate(cards):
        info_bits: list[str] = []
        if show_template and is_card_template(c):
            info_bits.append("template")
        if show_created:
            created_date = c.created_date.astimezone(timezone)
            info_bits.append(f"created {created_date.strftime('%Y-%m-%d')}")
        if show_updated:
            # Not sure if this is actually useful:
            date_last_activity = c.date_last_activity.astimezone(timezone)
            info_bits.append(f"updated {date_last_activity.strftime('%Y-%m-%d')}")
        if show_list:
            card_list_name = c.get_list().name  # type: ignore[attr-exists]
            info_bits.append(f"in {card_list_name!r}")
        if show_id:
            card_id = c.id  # type: ignore[attr-exists]
            info_bits.append(f"id {card_id}")
        start_or_due_nl = newline_before_start_due
        if show_start:
            json = c._json_obj  # pyright: ignore[reportPrivateUsage]
            assert json is not None
            start = json.get("start", "")
            if start:
                start_date = dateutil.parser.parse(start).astimezone(timezone)
                text = f"start on {start_date.strftime('%Y-%m-%d')}"
                if start_or_due_nl:
                    start_or_due_nl = False
                    text = "\n    " + text
                info_bits.append(text)
        if show_due:
            due_date = c.due_date
            if due_date:
                due_date = due_date.astimezone(timezone)
                text = f"due on {due_date.strftime('%Y-%m-%d at %I:%M%p')}"
                if start_or_due_nl:
                    start_or_due_nl = False
                    text = "\n    " + text
                info_bits.append(text)
        if show_url:
            url = c.short_url  # type: ignore[attr-exists]
            text = f"url {url}"
            if newline_before_url:
                text = "\n      " + text  # note: extra indent!
            info_bits.append(text)
        text = ", ".join(info_bits)
        card_name = c.name  # type: ignore[attr-exists]
        card_info.append([key(c), card_name, len(card_info), text, c])
    # `card_info` tuples are already ordered for comparability.
    card_info.sort()
    if show_index:
        for i in range(len(card_info)):
            card_info[i][3] = f"[{i+1}/{len(card_info)}] " + card_info[i][3]
    return ["    " + info for _, _, _, info, _ in card_info], [
        card for _, _, _, _, card in card_info
    ]


def print_cards(cards: Iterable[Card], **kwargs: Any) -> list[Card]:
    formatted, cards = format_cards(cards, **kwargs)
    for cf in formatted:
        print(cf)
    return cards
