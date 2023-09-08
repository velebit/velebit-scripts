#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data, \
    Column

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


def get_description(row):
    description = row[SRC_KEY_DESCRIPTION]
    description = regex.sub(r'\s+#\d+(?:\s.*)?$', '', description)
    description = description.rstrip()
    return description


def make_uniform_row(row):
    info = {
        Column.DATE: row[SRC_KEY_TRANSACTION_DATE],
        Column.POSTED_DATE: row[SRC_KEY_POSTED_DATE],
        Column.DEBIT: "{:.2f}".format(-float(row[SRC_KEY_DEBIT])),
        Column.CREDIT: "{:.2f}".format(float(row[SRC_KEY_CREDIT])),
        Column.SOURCE: get_source(row),
        Column.CATEGORY: row[SRC_KEY_CATEGORY],
        Column.DESCRIPTION: get_description(row),
    }
    return info


def make_uniform(data):
    return [make_uniform_row(row) for row in data]


def write_combined_csv_data(data, file):
    # Order by transaction date.
    write_csv_data(data, file)


# XXX TODO
def write_collated(data, collation_key, file):
    cat_totals = {}
    for row in data:
        cat = row[collation_key]
        if cat not in cat_totals:
            cat_totals[cat] = [0, 0, 0]
        cat_totals[cat][0] += 1
        if row[SRC_KEY_MINUS] != '':
            cat_totals[cat][1] += float(row[SRC_KEY_MINUS])
        if row[SRC_KEY_PLUS] != '':
            cat_totals[cat][2] += float(row[SRC_KEY_PLUS])
    cat_summary = []
    for k in sorted(cat_totals.keys(), key=lambda x: -sum(cat_totals[x][1:3])):
        instances = cat_totals[k][0]
        val_minus = ("{:.2f}".format(cat_totals[k][1]) if cat_totals[k][1] != 0
                     else '')
        val_plus = ("{:.2f}".format(cat_totals[k][2]) if cat_totals[k][2] != 0
                    else '')
        # print(f"{instances:2d} {k:50.50s} {val_minus:>10.10s}"
        #       f" {val_plus:>10.10s}")
        cat_summary.append({'#': instances, Column.XXX: k,
                            'Withdrawals': val_minus, 'Deposits': val_plus})
    write_csv_data(cat_summary, file)


def main():
    parser = argparse.ArgumentParser(description='Read Capital One CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_cap_one_data(f))
    write_combined_csv_data(data, 'CapitalOne-combined.csv')
    # XXX TODO
    # data = add_summaries(data)
    # write_collated(data, Column.XXX, 'CapitalOne-summary.csv')
    # write_collated(data, SRC_KEY_CATEGORY, 'CapitalOne-summary-cat.csv')


if __name__ == '__main__':
    main()
