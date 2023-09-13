#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data, \
    Date, Money, apply_remapping, Column

SRC_KEY_DATE = 'Datetime'
SRC_KEY_TYPE = 'Type'
SRC_KEY_NOTE = 'Note'
SRC_KEY_FROM = 'From'
SRC_KEY_TO = 'To'
SRC_KEY_AMOUNT = 'Amount (total)'

# Types where "From" and "To" are reversed, compared to the other fields
SRC_TYPES_BACKWARDS = ('Charge')


def read_venmo_data(file):
    reader = read_csv_data(file, remove_until=(lambda ln:
                                               regex.search(SRC_KEY_DATE, ln)))
    return [{k: v for k, v in row.items() if k != '' or v != ''}
            for row in reader if row[SRC_KEY_DATE] != '']


def get_us_and_them(row):
    if row[SRC_KEY_TYPE] in SRC_TYPES_BACKWARDS:
        dst, src = row[SRC_KEY_FROM], row[SRC_KEY_TO]
    else:
        src, dst = row[SRC_KEY_FROM], row[SRC_KEY_TO]
    if Money.parse(row[SRC_KEY_AMOUNT]).amount > 0:
        return dst, src
    else:
        return src, dst


def get_source(row):
    return "Venmo - " + get_us_and_them(row)[0]


def get_category(row):
    return '(Venmo other)'


def get_description(row):
    return get_us_and_them(row)[1]


def get_comment(row):
    return row[SRC_KEY_NOTE] + ' [' + row[SRC_KEY_TYPE] + ']'


def make_uniform_row(row):
    amount = Money.parse(row[SRC_KEY_AMOUNT])
    info = {
        Column.DATE: Date.parse(row[SRC_KEY_DATE]).format(),
        Column.POSTED_DATE: Date.parse(row[SRC_KEY_DATE]).format(),
        Column.DEBIT: amount.if_negative().format(),
        Column.CREDIT: amount.if_positive().format(),
        Column.SOURCE: get_source(row),
        Column.CATEGORY: get_category(row),
        Column.DESCRIPTION: get_description(row),
        Column.COMMENT: get_comment(row),
    }
    return info


def make_uniform(data):
    return apply_remapping([make_uniform_row(row) for row in data])


def main():
    parser = argparse.ArgumentParser(
        description='Preprocess Venmo CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_venmo_data(f))
    data = sorted(data, key=lambda d: Date.parse(d[SRC_KEY_DATE]).format())
    write_csv_data(data, 'Venmo-combined.csv')
    data = make_uniform(data)
    write_csv_data(data, 'Venmo-uniform.csv')


if __name__ == '__main__':
    main()
