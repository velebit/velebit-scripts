#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data, \
    Date, Money, apply_remapping, Column

SRC_KEY_DATE = '<Date>'
SRC_KEY_CHECK_NUM = '<CheckNum>'
SRC_KEY_DESCRIPTION = '<Description>'
SRC_KEY_DEBIT = '<Withdrawal Amount>'
SRC_KEY_CREDIT = '<Deposit Amount>'
SRC_KEY_ADDITIONAL_INFO = '<Additional Info>'


def read_cam_trust_data(file):
    data = list(read_csv_data(file, filter=(lambda ln: len(ln) > 0)))
    return list(reversed(data))


def get_source(row):
    if len(row[SRC_KEY_CHECK_NUM]) > 0:
        return f"CamTr check {row[SRC_KEY_CHECK_NUM]}"
    else:
        return "CamTr"


def get_category(row):
    return ''


def get_description(row):
    desc = row[SRC_KEY_DESCRIPTION]
    info = row[SRC_KEY_ADDITIONAL_INFO]
    info = regex.sub(r', Inc\.', '', info)
    info = regex.sub(r'^POS PURCHASE TERMINAL\s+\S+\s+(?:\d+\s+)?', '', info)
    info = regex.sub(r'^SURCHARGE AMOUNT TERMINAL\s+\S+\s+(?:\d+\s+)?',
                     'Surcharge ', info)
    info = regex.sub(r'^CASH WITHDRAWAL TERMINAL\s+\S+\s+(?:\d+\s+)?',
                     '', info)
    info = regex.sub(r'^(CAPITAL ONE|COVIDIEN LP)\s.*', '\\1', info)
    # info = regex.sub(r'\s+\#?(?<!\d)(?<!MY)\d.*', '', info)
    info = regex.sub(r'\s{2,}', ' ', info)
    if regex.match(r'^PREAUTHORIZED (WD|CREDIT)$', desc):
        return info
    elif regex.match(r'^ELECTRONIFIED CHECK$', desc):
        return info
    elif info == '' or regex.match(r'^ATM ', desc):
        return desc
    else:
        return desc + ": " + info


def make_uniform_row(row):
    info = {
        Column.DATE: Date.parse(row[SRC_KEY_DATE]).format(),
        Column.POSTED_DATE: Date.parse(row[SRC_KEY_DATE]).format(),
        Column.DEBIT: Money.parse(row[SRC_KEY_DEBIT]).format(),
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
        description='Preprocess Cambridge Trust CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_cam_trust_data(f))
    data = sorted(data, key=lambda d: Date.parse(d[SRC_KEY_DATE]).format())
    write_csv_data(data, 'CamTrust-combined.csv')
    data = make_uniform(data)
    write_csv_data(data, 'CamTrust-uniform.csv')


if __name__ == '__main__':
    main()
