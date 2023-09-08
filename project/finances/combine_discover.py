#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data

DESCRIPTION_KEY = 'Description'
CATEGORY_KEY = 'Category'
AMOUNT_KEY = 'Amount'
SUMMARY_KEY = 'Summary'


def get_summary(row):
    summary = row[DESCRIPTION_KEY]
    summary = regex.sub(r'\d{3,}\S{2}$', '', summary)
    summary = regex.sub(r'\s+#\d+(?:\s.*)?$', '', summary)
    summary = summary.rstrip()
    return summary


def add_summaries(data):
    return [{**row, SUMMARY_KEY: get_summary(row)} for row in data]


def read_discover_data(file):
    data = list(read_csv_data(file, filter=(lambda ln: len(ln) > 0)))
    for row in data:
        if row[AMOUNT_KEY] != '':
            row[AMOUNT_KEY] = "{:.2f}".format(-float(row[AMOUNT_KEY]))
    return data


def write_collated(data, collation_key, file):
    cat_totals = {}
    for row in data:
        cat = row[collation_key]
        if cat not in cat_totals:
            cat_totals[cat] = [0, 0, 0]
        cat_totals[cat][0] += 1
        amount = float(regex.sub(r',', '', row[AMOUNT_KEY]))
        if amount < 0:
            cat_totals[cat][1] += amount
        else:
            cat_totals[cat][2] += amount
    cat_summary = []
    for k in sorted(cat_totals.keys(), key=lambda x: -sum(cat_totals[x][1:3])):
        instances = cat_totals[k][0]
        val_minus = ("{:.2f}".format(cat_totals[k][1]) if cat_totals[k][1] != 0
                     else '')
        val_plus = ("{:.2f}".format(cat_totals[k][2]) if cat_totals[k][2] != 0
                    else '')
        # print(f"{instances:2d} {k:50.50s} {val_minus:>10.10s}"
        #       f" {val_plus:>10.10s}")
        cat_summary.append({'#': instances, SUMMARY_KEY: k,
                            'Withdrawals': val_minus, 'Deposits': val_plus})
    write_csv_data(cat_summary, file)


def main():
    parser = argparse.ArgumentParser(description='Read Discover CSV')
    # 'Discover-combined.csv'
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_discover_data(f))
    write_csv_data(data, 'Discover-combined.csv')
    # XXX TODO
    # data = add_summaries(data)
    # write_collated(data, SUMMARY_KEY, 'Discover-summary.csv')
    # write_collated(data, CATEGORY_KEY, 'Discover-summary-cat.csv')


if __name__ == '__main__':
    main()
