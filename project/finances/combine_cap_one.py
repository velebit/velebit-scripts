#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data, \
    Date, Money, apply_remapping, Column

SRC_KEY_TRANSACTION_DATE = 'Transaction Date'
SRC_KEY_POSTED_DATE = 'Posted Date'
SRC_KEY_CARD_NO = 'Card No.'
SRC_KEY_DESCRIPTION = 'Description'
SRC_KEY_CATEGORY = 'Category'
SRC_KEY_DEBIT = 'Debit'
SRC_KEY_CREDIT = 'Credit'


def read_cap_one_data(file):
    data = list(read_csv_data(file, filter=(lambda ln: len(ln) > 0)))
    return data


def get_source(row):
    if len(row[SRC_KEY_CARD_NO]) > 0:
        return f"CapOne card {row[SRC_KEY_CARD_NO]}"
    else:
        return "CapOne"


def get_category(row):
    return '(' + row[SRC_KEY_CATEGORY] + ')'


def get_description(row):
    description = row[SRC_KEY_DESCRIPTION]
    description = regex.sub(r'\s+#\d+(?:\s.*)?$', '', description)
    description = description.rstrip()
    return description


def make_uniform_row(row):
    info = {
        Column.DATE: Date.parse(row[SRC_KEY_TRANSACTION_DATE]).format(),
        Column.POSTED_DATE: Date.parse(row[SRC_KEY_POSTED_DATE]).format(),
        Column.DEBIT: (-Money.parse(row[SRC_KEY_DEBIT])).format(),
        Column.CREDIT: Money.parse(row[SRC_KEY_CREDIT]).format(),
        Column.SOURCE: get_source(row),
        Column.CATEGORY: get_category(row),
        Column.DESCRIPTION: get_description(row),
        Column.COMMENT: '',
    }
    return info


def make_uniform(data):
    return apply_remapping([make_uniform_row(row) for row in data])


def main():
    parser = argparse.ArgumentParser(
        description='Preprocess Capital One CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_cap_one_data(f))
    data = sorted(data,
                  key=lambda d: Date.parse(
                      d[SRC_KEY_TRANSACTION_DATE]).format())
    write_csv_data(data, 'CapitalOne-combined.csv')
    data = make_uniform(data)
    write_csv_data(data, 'CapitalOne-uniform.csv')


if __name__ == '__main__':
    main()
