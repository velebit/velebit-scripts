#!/usr/bin/env -S python3 -B
import argparse
import re

from budget_transactions import read_csv_data, write_csv_data, \
    RuleColumn, is_string_true, Money


def strip_regex_leading(text):
    # Remove "strippable" regex prefixes to yield a somewhat sortable string.
    # Doesn't do everything; for example, '[...]' would stay in place.
    return re.sub(r'(?:\\b|\^|\(\?:\|\()+', '', text)


def needs_manual_update(row):
    return (len(row[RuleColumn.OUT_CATEGORY]) > 0
            and row[RuleColumn.OUT_CATEGORY][0] == '?')


def get_key_amount_if_incomplete(row):
    if needs_manual_update(row) and 'total' in row:
        return Money.parse(row['total'])
    else:
        return Money()


def get_key_description(row):
    if needs_manual_update(row):
        return '?'
    if row[RuleColumn.OUT_DESCRIPTION] == '':
        return strip_regex_leading(row[RuleColumn.IN_DESCRIPTION]).lower()
    return row[RuleColumn.OUT_DESCRIPTION].lower()


def get_key_category(row):
    if needs_manual_update(row):
        return '?'
    return row[RuleColumn.OUT_CATEGORY]


def get_key_continue_logical(row):
    return int(is_string_true(row[RuleColumn.CONTINUE]))


def sort_rules(filename, sort_incomplete_by_amount=False):
    print(f"Reading {filename}")
    data = read_csv_data(filename, normalize=None)

    # sorted() is a stable sort, so the last sort is most major, but when it
    # comes to elements whose key compares equal, the preceding sorts define
    # more minor keys (most minor to most major).
    if sort_incomplete_by_amount:
        # Data from draft_missed_rules comes from summary data, which is
        # already sorted by total but also broken down by category after
        # sorting. So re-sorting by amount messes up category collation,
        # which is why by default we don't.
        data = sorted(data, key=get_key_amount_if_incomplete)
    data = sorted(data, key=get_key_description)
    data = sorted(data, key=get_key_category)
    data = sorted(data, key=get_key_continue_logical, reverse=True)

    write_csv_data(data, filename)
    print(f"Wrote {filename}")


def main():
    parser = argparse.ArgumentParser(description='Sort rule CSV')
    parser.add_argument('FILE', help='CSV file')
    opts = parser.parse_args()
    sort_rules(opts.FILE)


if __name__ == '__main__':
    main()
