#!/not-executable/python3
import json
import os
import sys
import trello

## constants

# keys for label manipulation
ADD_LABELS = 'add'
REMOVE_LABELS = 'rm'
RETIRE_LABELS = 'retire'

## generic utility functions

def flatten(collection_of_collections):
    return [element for collection in collection_of_collections
            for element in collection]

def intersection(first, *rest):
    return frozenset(first).intersection(*(frozenset(s) for s in rest))

def difference(first, *rest):
    return frozenset(first).difference(*(frozenset(s) for s in rest))

def union(first, *rest):
    return frozenset(first).union(*(frozenset(s) for s in rest))

## authentication and client object management

def get_auth_file_name():
    home_dir = os.getenv("HOME")
    assert home_dir is not None, "HOME needs to be set"
    return home_dir + "/.trello_auth.json"

def read_auth_data():
    with open(get_auth_file_name(), "r", encoding="utf-8") as f:
        auth = json.load(f)
    assert 'api_key' in auth
    assert 'api_secret' in auth
    return auth

def create_auth_token(auth, save_if_updated=True):
    token = trello.create_oauth_token(key=auth['api_key'],
                                      secret=auth['api_secret'])
    for k in token:
        auth[k] = token[k]
    if save_if_updated:
        with open(get_auth_file_name(), "w", encoding="utf-8") as f:
            json.dump(auth, f)
    assert 'oauth_token' in auth
    assert 'oauth_token_secret' in auth
    return auth

def get_full_auth_data(auth=None, allow_update=True, save_if_updated=True):
    if auth is None:
        auth = read_auth_data()
    if 'oauth_token' not in auth or 'oauth_token_secret' not in auth:
        if allow_update:
            auth = create_auth_token(auth, save_if_updated)
        else:
            assert False, ('Refusing to create auth token since stdin may be' +
                           'piped; try e.g. trello_boards?')
            # If assertion fails, other apps will create a token we can use!
    return auth

def create_client(auth=None):
    if auth is None:
        auth = get_full_auth_data()
    client = trello.TrelloClient(api_key=auth['api_key'],
                                 api_secret=auth['api_secret'],
                                 token=auth['oauth_token'],
                                 token_secret=auth['oauth_token_secret'])
    return client

## creating and applying selector condition functions

def item_id_is(item_id):
    return lambda i: i.id == item_id

def item_name_is(item_name):
    return lambda i: i.name == item_name

def item_is_open():
    return lambda i: not i.closed

def select_all(collection, *conditions):
    return [i for i in collection if all([c(i) for c in conditions])]

def select_one(collection, *conditions):
    # return the first match or None
    return [*select_all(collection, *conditions), None][0]

## accessing existing boards, labels and lists

def get_open_board_by_id(client, id):
    return select_one(client.list_boards(),
                      item_is_open(), item_id_is(id))
def get_open_board_by_name(client, name):
    return select_one(client.list_boards(),
                      item_is_open(), item_name_is(name))

def get_multiple_labels_by_name(board, names):
    all_labels = board.get_labels()
    return {n: select_one(all_labels, item_name_is(n)) for n in names}

def get_any_list_by_id(board, id):
    return select_one(board.list_lists(), item_id_is(id))
def get_any_list_by_name(board, name):
    return select_one(board.list_lists(), item_name_is(name))

def get_open_list_by_id(board, id):
    return select_one(board.open_lists(), item_id_is(id))
def get_open_list_by_name(board, name):
    return select_one(board.open_lists(), item_name_is(name))

## getting a board handle, with authentication setup and logging

def get_board(board_id, board_name, auth=None, verbosity=0):
    verbosity_threshold, extra_msg = 2, ''
    board = get_open_board_by_id(create_client(auth=auth), board_id)
    if board is None:
        board = get_open_board_by_name(create_client(auth=auth), board_name)
        if board_name != board_id:
            verbosity_threshold, extra_msg = 1, '*by name*, fix the ID!'
    assert board is not None, "No open board found"
    if verbosity >= verbosity_threshold:
        print(f"(T) Selected board '{board.name}' ({board.id}){extra_msg}",
              file=sys.stderr)
    return board

## creating labels

def get_or_create_labels(board, names, verbosity=0):
    label_map = get_multiple_labels_by_name(board, names)
    for label in tuple(label_map.keys()):
        if label_map[label] is not None:
            if verbosity >= 2:
                print("(T) Selected label '{name}' ({id})"
                      .format(name=label_map[label].name,
                              id=label_map[label].id),
                      file=sys.stderr)
        else:
            label_map[label] = board.add_label(label, "black")
            assert label_map[label] is not None
            if verbosity >= 2:
                print("(T) Created label  '{name}' ({id})"
                      .format(name=label_map[label].name,
                              id=label_map[label].id),
                      file=sys.stderr)
    return label_map.values()

## creating lists

def get_list(board, list_id, list_name, verbosity=0):
    verbosity_threshold, extra_msg = 1, ''
    tlist = get_any_list_by_id(board, list_id)
    if tlist is None:
        tlist = get_any_list_by_name(board, list_name)
        verbosity_threshold, extra_msg = 0, '*by name*, fix the ID!'
    if tlist is not None:
        if verbosity >= verbosity_threshold:
            print(f"(T) Selected list  '{tlist.name}' ({tlist.id}){extra_msg}",
                  file=sys.stderr)
    return tlist

def get_or_create_list(board, list_id, list_name, verbosity=0):
    tlist = get_list(board, list_id, list_name, verbosity)
    if tlist is None:
        tlist = board.add_list(list_name, pos="top")
        assert tlist is not None, "List creation returned None"
        if verbosity >= 0:
            print("(T) Created list  '{name}' ({id})"
                  .format(name=tlist.name,
                          id=tlist.id),
                  file=sys.stderr)
    assert tlist is not None, "No list found or created"
    return tlist

def reopen_list(tlist, *, verbosity=0, dry_run=False):
    if tlist.closed:
        if dry_run:
            if verbosity >= 0:
                print("(T) Did not reopen list '{name}' ({id})"
                      .format(name=tlist.name,
                              id=tlist.id),
                      file=sys.stderr)
        else:
            tlist.open()
            if verbosity >= 0:
                print("(T) Reopened list '{name}' ({id})"
                      .format(name=tlist.name,
                              id=tlist.id),
                      file=sys.stderr)

## creating cards

def get_cards_with_info(board, cards, verbosity=0):
    existing = dict()
    for c in board.open_cards():
        existing.setdefault(c.name, []).append(c)
    cards = [{**info, 'cards': existing.get(info['name'], [])}
             for info in cards]
    for info in cards:
        if len(info['cards']) > 0:
            if verbosity >= 1:
                if len(info['cards']) == 1:
                    print("(T) Card '{name}' already exists!"
                          .format(name=info['name']),
                          file=sys.stderr)
                else:
                    print("(T) {num} cards matching '{name}' already exist!"
                          .format(name=info['name'], num=len(info['cards'])),
                          file=sys.stderr)
    return cards

def get_or_create_cards_with_info(tlist, cards, labels=None, verbosity=0):
    cards = get_cards_with_info(tlist.board, cards, verbosity=verbosity)
    for info in cards:
        if len(info['cards']) == 0:
            reopen_list(tlist, verbosity=verbosity)
            card = tlist.add_card(info['name'], desc=info['desc'],
                                  labels=labels)
            if verbosity >= 0:
                print("(T) Card '{name}' created.".format(name=card.name),
                      file=sys.stderr)
            info['cards'] = [card]
    return cards

# backwards compatibility
def maybe_create_card(tlist, name, description=None, labels=None, verbosity=0):
    cards = get_or_create_cards_with_info(tlist,
                                          {'name': name, 'desc': description},
                                          labels=labels, verbosity=verbosity)
    return cards_from_info(cards)

def cards_from_info(info):
    return flatten((c['cards'] for c in info))

def get_or_create_cards(tlist, cards, labels=None, verbosity=0):
    return cards_from_info(
        get_or_create_cards_with_info(tlist, cards, labels, verbosity))

## moving cards between lists

def move_cards_to_list(cards, dst_list, *, verbosity=0, dry_run=False):
    for c in cards:
        prev_list = c.get_list()
        reopen_list(dst_list, verbosity=verbosity, dry_run=dry_run)
        if dry_run:
            if verbosity >= 0:
                print("(T) Did not move card '{name}' from '{src}' to '{dst}'."
                      .format(name=c.name, src=prev_list.name,
                              dst=dst_list.name),
                      file=sys.stderr)
        else:
            c.change_list(dst_list.id)
            if verbosity >= 0:
                print("(T) Moved card '{name}' from '{src}' to '{dst}'."
                      .format(name=c.name, src=prev_list.name,
                              dst=dst_list.name),
                      file=sys.stderr)

def move_cards_from_lists_to_list(cards, src_lists, dst_list,
                                  *, verbosity=0, dry_run=False):
    moving = [(c, (c.get_list() in src_lists)) for c in cards]
    if verbosity >= 3:
        for card in (m[0] for m in moving if not m[1]):
            print("(T) Card '{name}' is in list {lst}, not in filter lists"
                  .format(name=card.name, lst=card.get_list().name),
                  file=sys.stderr)
    move_cards_to_list((m[0] for m in moving if m[1]),
                       dst_list, verbosity=verbosity, dry_run=dry_run)

def move_cards_not_in_lists_to_list(cards, excl_lists, dst_list,
                                    *, verbosity=0, dry_run=False):
    moving = [(c, (c.get_list() not in excl_lists)) for c in cards]
    if verbosity >= 3:
        for card in (m[0] for m in moving if not m[1]):
            print("(T) Card '{name}' is in list {lst}, in exclude lists"
                  .format(name=card.name, lst=card.get_list().name),
                  file=sys.stderr)
    move_cards_to_list((m[0] for m in moving if m[1]),
                       dst_list, verbosity=verbosity, dry_run=dry_run)

## directly managing labels on a card

def add_labels_to_card(card, labels_to_add, verbosity=0):
    missing_labels = difference(labels_to_add, card.labels)
    if len(missing_labels) > 0:
        for l in missing_labels:
            card.add_label(l)
        if verbosity >= 0:
            label_info = ", ".join(["'" + l.name + "'"
                                    for l in missing_labels])
            print("(T) Updated card '{name}': added label(s) {labels}."
                  .format(name=card.name, labels=label_info),
                  file=sys.stderr)
        return True
    else:
        return False

def remove_labels_from_card(card, labels_to_remove, verbosity=0):
    extra_labels = intersection(labels_to_remove, card.labels)
    if len(extra_labels) > 0:
        for l in extra_labels:
            card.remove_label(l)
        if verbosity >= 0:
            label_info = ", ".join(["'" + l.name + "'"
                                    for l in extra_labels])
            print("(T) Updated card '{name}': removed label(s) {labels}."
                  .format(name=card.name, labels=label_info),
                  file=sys.stderr)
        return True
    else:
        return False

## managing labels on cards according to rules

def look_up_label_objects_in_label_rules(board, label_str_rules, verbosity=0):
    return [ {k: frozenset(get_or_create_labels(board, v, verbosity=verbosity))
              for k, v in lsr.items()}
            for lsr in label_str_rules ]

def get_default_labels_from_rules(label_rules):
    return frozenset(flatten(
        (lr[ADD_LABELS] for lr in label_rules if ADD_LABELS in lr)))

def update_card_labels(cards, label_rules, verbosity=0):
    for card in cards:
        want_labels = frozenset(card.labels)
        for rule in label_rules:
            if ADD_LABELS in rule:
                missing = difference(rule[ADD_LABELS], want_labels)
                # if both ADD and REMOVE, -REMOVE is conditional on +ADD
                if len(missing) > 0:
                    want_labels = union(want_labels, rule[ADD_LABELS])
                    if REMOVE_LABELS in rule:
                        want_labels = difference(want_labels,
                                                 rule[REMOVE_LABELS])
            elif REMOVE_LABELS in rule:
                # if REMOVE with no ADD, -REMOVE is unconditional
                want_labels = difference(want_labels, rule[REMOVE_LABELS])
        add_labels_to_card(card, difference(want_labels, card.labels),
                           verbosity=verbosity)
        remove_labels_from_card(card, difference(card.labels, want_labels),
                                verbosity=verbosity)
        # The assertion is unreliable because the card.labels update is delayed
        #assert frozenset(card.labels) == want_labels

def update_orphan_labeled_tasks(board, label_rules, tasks, verbosity=0):
    task_names = [t['name'] for t in tasks]
    cards_not_in_tasks_list = \
        [c for c in board.open_cards() if c.name not in task_names]
    for card in cards_not_in_tasks_list:
        want_labels = frozenset(card.labels)
        for rule in label_rules:
            # Only look at rules that have both RETIRE and ADD specified.
            # For those rules, if -ADD removes anything, do +RETIRE.
            if ADD_LABELS in rule and RETIRE_LABELS in rule:
                extra = intersection(card.labels, rule[ADD_LABELS])
                if len(extra) > 0:
                    want_labels = difference(want_labels, rule[ADD_LABELS])
                    want_labels = union(want_labels, rule[RETIRE_LABELS])
        add_labels_to_card(card, difference(want_labels, card.labels),
                           verbosity=verbosity)
        remove_labels_from_card(card, difference(card.labels, want_labels),
                                verbosity=verbosity)
        # The assertion is unreliable because the card.labels update is delayed
        #assert frozenset(card.labels) == want_labels
