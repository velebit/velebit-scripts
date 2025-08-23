#!/not-executable/python3
import dateutil
import json
import os
import sys
import trello
from bert_task_utilities import flatten, \
    difference, union, intersection, \
    select_one


# ===== constants =====

# keys for label manipulation
ADD_LABELS = 'add'
REMOVE_LABELS = 'rm'
RETIRE_LABELS = 'retire'
IF_PRESENT_ANY_LABELS = 'if+any'
IF_MISSING_ALL_LABELS = 'if-all'


# ===== authentication and client object management =====

def get_auth_file_name():
    home_dir = os.getenv("HOME")
    assert home_dir is not None, "HOME needs to be set"
    return home_dir + "/.config/bert_trello/auth.json"


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


# ===== creating and applying selector condition functions =====

def item_id_is(item_id):
    return lambda i: i.id == item_id


def item_name_is(item_name):
    return lambda i: i.name == item_name


def item_is_open():
    return lambda i: not i.closed


# ===== accessing existing boards, labels and lists =====

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


# ===== getting a board handle, with authentication setup and logging =====


def get_board(board_id, board_name, auth=None, verbosity=0):
    verbosity_threshold, extra_msg = 2, ''
    client = create_client(auth=auth)
    board = get_open_board_by_id(client, board_id)
    if board is None:
        board = get_open_board_by_name(client, board_name)
        if board_name != board_id:
            verbosity_threshold, extra_msg = 1, '*by name*, fix the ID!'
    assert board is not None, "No open board found"
    if verbosity >= verbosity_threshold:
        print(f"(T) Selected board '{board.name}' ({board.id}){extra_msg}",
              file=sys.stderr)
    return board


# ===== creating labels =====

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


# ===== creating lists =====

def get_list(board, list_id, list_name, verbosity=0):
    verbosity_threshold, extra_msg = 1, ''
    tlist = None
    if list_id is not None:
        tlist = get_any_list_by_id(board, list_id)
    if tlist is None and list_name is not None:
        tlist = get_any_list_by_name(board, list_name)
        if list_id is not None:
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


# ===== creating cards =====

def is_card_template(card):
    # HACK: this accesses internal JSON data and may not be generally reliable.
    #   But it will work fine for cards retrieved via board.open_cards(), since
    #   the internal JSON data will be populated in that case.
    json = card._json_obj
    if 'cover' in json:
        if 'isTemplate' in json['cover']:
            return json['cover']['isTemplate']  # what the API docs specify
    if 'isTemplate' in json:
        return json['isTemplate']  # what the API actually currently returns
    return False


def get_cards_with_info(board, cards, /, include_templates=True):
    existing = dict()
    for c in board.open_cards():
        if include_templates or not is_card_template(c):
            existing.setdefault(c.name, []).append(c)
    return [{**info, 'cards': existing.get(info['name'], [])}
            for info in cards]


def log_existing_cards(cards, /, verbosity=0, check_together=False):
    if verbosity < 0:
        return  # verbosity 0 required to log
    for info in cards:
        if len(info['cards']) == 1 and verbosity < 1:
            continue  # at verbosity 0 need >1 card, don't bother checking more
        if check_together:
            counts = (len(info['cards']),)
        else:
            counts = (len([c for c in info['cards']
                           if not is_card_template(c)]),
                      len([c for c in info['cards']
                           if is_card_template(c)]))
        have_count_above_1 = any([n > 1 for n in counts])
        if have_count_above_1 or verbosity >= 1:
            counts_str = '+'.join([str(n) for n in counts])
            use_singular = (len(counts) == 1 and counts[0] == 1)
            if use_singular:
                print(f"(T) {counts_str} card matching {info['name']!r}"
                      " already exists!",
                      file=sys.stderr)
            else:
                print(f"(T) {counts_str} cards matching {info['name']!r}"
                      " already exist!",
                      file=sys.stderr)


def create_cards_with_info(tlist, cards, labels=None, verbosity=0):
    for info in cards:
        reopen_list(tlist, verbosity=verbosity)
        card = tlist.add_card(info['name'], desc=info['desc'],
                              labels=labels)
        if verbosity >= 0:
            print("(T) Card '{name}' created.".format(name=card.name),
                  file=sys.stderr)
        info.setdefault('cards', []).append(card)
    return cards


def get_or_create_cards_with_info(tlist, cards, labels=None, /, verbosity=0,
                                  log_existing_together=False):
    cards = get_cards_with_info(tlist.board, cards)
    log_existing_cards(cards, verbosity=verbosity,
                       check_together=log_existing_together)
    missing = [c for c in cards
               if 'cards' not in c or len(c['cards']) == 0]
    if len(missing) > 0:
        # Note: will update `cards` by updating members of `missing`!
        create_cards_with_info(tlist, missing,
                               labels=labels, verbosity=verbosity)
    return cards


def grouped_cards_from_info(info):
    return [list(c['cards']) for c in info]


def cards_from_info(info):
    return flatten(grouped_cards_from_info(info))


def get_or_create_cards(tlist, cards, labels=None, verbosity=0):
    return cards_from_info(
        get_or_create_cards_with_info(tlist, cards, labels, verbosity))


# ===== moving cards between lists =====

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


# ===== directly managing labels on a card =====

def add_labels_to_card(card, labels_to_add, verbosity=0):
    missing_labels = difference(labels_to_add, card.labels)
    if len(missing_labels) > 0:
        for ml in missing_labels:
            card.add_label(ml)
        if verbosity >= 0:
            label_info = ", ".join(["'" + ml.name + "'"
                                    for ml in missing_labels])
            print("(T) Updated card '{name}': added label(s) {labels}."
                  .format(name=card.name, labels=label_info),
                  file=sys.stderr)
        return True
    else:
        return False


def remove_labels_from_card(card, labels_to_remove, verbosity=0):
    extra_labels = intersection(labels_to_remove, card.labels)
    if len(extra_labels) > 0:
        for el in extra_labels:
            card.remove_label(el)
        if verbosity >= 0:
            label_info = ", ".join(["'" + el.name + "'"
                                    for el in extra_labels])
            print("(T) Updated card '{name}': removed label(s) {labels}."
                  .format(name=card.name, labels=label_info),
                  file=sys.stderr)
        return True
    else:
        return False


# ===== managing labels on cards according to rules =====

def look_up_label_objects_in_label_rules(board, label_str_rules, verbosity=0):
    return [{k: frozenset(get_or_create_labels(board, v, verbosity=verbosity))
             for k, v in lsr.items()}
            for lsr in label_str_rules]


def get_default_labels_from_rules(label_rules):
    return frozenset(flatten(
        (lr[ADD_LABELS] for lr in label_rules
         if ADD_LABELS in lr and IF_PRESENT_ANY_LABELS not in lr)))


def update_card_labels(cards, label_rules, verbosity=0):
    for card in cards:
        want_labels = frozenset(card.labels)
        for rule in label_rules:
            # sanity check: if both ADD and REMOVE, there should be no overlap
            if ADD_LABELS in rule and REMOVE_LABELS in rule:
                add_and_remove = intersection(
                    rule[ADD_LABELS], rule[REMOVE_LABELS])
                assert len(add_and_remove) == 0, \
                    f"Labels are being added AND removed: {add_and_remove}"
            # sanity check: if multiple IFs, there should be no overlap
            if IF_PRESENT_ANY_LABELS in rule and IF_MISSING_ALL_LABELS in rule:
                present_and_missing = intersection(
                    rule[IF_PRESENT_ANY_LABELS], rule[IF_MISSING_ALL_LABELS])
                assert len(present_and_missing) == 0, \
                    ("Checking for labels to be present AND missing:"
                     f" {present_and_missing}")
            # apply the rules
            if IF_PRESENT_ANY_LABELS in rule:
                present_labels = intersection(
                    want_labels, rule[IF_PRESENT_ANY_LABELS])
                if len(present_labels) == 0:
                    continue  # rule's condition was not met
            if IF_MISSING_ALL_LABELS in rule:
                missing_labels = intersection(
                    want_labels, rule[IF_MISSING_ALL_LABELS])
                if len(missing_labels) > 0:
                    continue  # rule's condition was not met
            if ADD_LABELS in rule:
                want_labels = union(want_labels, rule[ADD_LABELS])
            if REMOVE_LABELS in rule:
                want_labels = difference(want_labels, rule[REMOVE_LABELS])
        add_labels_to_card(card, difference(want_labels, card.labels),
                           verbosity=verbosity)
        remove_labels_from_card(card, difference(card.labels, want_labels),
                                verbosity=verbosity)
        # The assertion is unreliable because the card.labels update is delayed
#        assert frozenset(card.labels) == want_labels


def update_orphan_labeled_tasks(board, label_rules, tasks, verbosity=0):
    task_names = [t['name'] for t in tasks]
    cards_not_in_tasks_list = \
        [c for c in board.open_cards() if c.name not in task_names]
    for card in cards_not_in_tasks_list:
        want_labels = frozenset(card.labels)
        for rule in label_rules:
            # Only look at rules that have RETIRE and either ADD or REMOVE
            # specified. For those rules, if either -ADD or -REMOVE removes
            # anything, also do +RETIRE.
            if RETIRE_LABELS not in rule:
                continue
            try_remove = []
            if ADD_LABELS in rule:
                try_remove.extend(rule[ADD_LABELS])
            if REMOVE_LABELS in rule:
                try_remove.extend(rule[REMOVE_LABELS])
            if len(try_remove):
                extra = intersection(card.labels, try_remove)
                if len(extra) > 0:
                    want_labels = difference(want_labels, try_remove)
                    want_labels = union(want_labels, rule[RETIRE_LABELS])
        add_labels_to_card(card, difference(want_labels, card.labels),
                           verbosity=verbosity)
        remove_labels_from_card(card, difference(card.labels, want_labels),
                                verbosity=verbosity)
        # The assertion is unreliable because the card.labels update is delayed
#        assert frozenset(card.labels) == want_labels


# ===== formatting and printing card information in a uniform way =====

def format_cards(cards, *, key=None,
                 show_template=False, show_created=True, show_updated=True,
                 show_list=True, show_id=False, show_start=False,
                 show_due=False, newline_before_start_due=True,
                 show_url=True, newline_before_url=True,
                 timezone=None):
    if key is None:
        def key(c):
            return c.created_date
    card_info = list()
    for c in cards:
        info_bits = []
        if show_template and is_card_template(c):
            info_bits.append("template")
        if show_created:
            created_date = c.created_date.astimezone(timezone)
            info_bits.append(
                f"created {created_date.strftime('%Y-%m-%d')}")
        if show_updated:
            # Not sure if this is actually useful:
            date_last_activity = c.date_last_activity.astimezone(timezone)
            info_bits.append(
                f"updated {date_last_activity.strftime('%Y-%m-%d')}")
        if show_list:
            info_bits.append(f"in {c.get_list().name!r}")
        if show_id:
            info_bits.append(f"id {c.id}")
        start_or_due_nl = newline_before_start_due
        if show_start:
            start = c._json_obj.get('start', '')
            if start:
                start_date = dateutil.parser.parse(start).astimezone(timezone)
                info = f"start on {start_date.strftime('%Y-%m-%d')}"
                if start_or_due_nl:
                    start_or_due_nl = False
                    info = "\n    " + info
                info_bits.append(info)
        if show_due:
            due_date = c.due_date
            if due_date:
                due_date = due_date.astimezone(timezone)
                info = f"due on {due_date.strftime('%Y-%m-%d at %I:%M%p')}"
                if start_or_due_nl:
                    start_or_due_nl = False
                    info = "\n    " + info
                info_bits.append(info)
        if show_url:
            info = f"url {c.short_url}"
            if newline_before_url:
                info = "\n      " + info  # note: extra indent!
            info_bits.append(info)
        info = "    " + ", ".join(info_bits)
        card_info.append((key(c), c.name, len(card_info), info))
    # `card_info` tuples are already ordered for comparability.
    card_info.sort()
    return [info for _, _, _, info in card_info]


def print_cards(cards, **kwargs):
    for cf in format_cards(cards, **kwargs):
        print(cf)
