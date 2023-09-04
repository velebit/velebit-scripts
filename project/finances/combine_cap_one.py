#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data

DESCRIPTION_KEY = 'Description'
CATEGORY_KEY = 'Category'
MINUS_KEY = 'Debit'
PLUS_KEY = 'Credit'
SOURCE_KEY = 'Source'
SUMMARY_KEY = 'Summary'


# def add_source(data, source):
#     return [{**row, SOURCE_KEY: source} for row in data]


def get_summary(row):
    summary = row[DESCRIPTION_KEY]
    summary = regex.sub(r'\s+#\d+(?:\s.*)?$', '', summary)
    summary = summary.rstrip()
    return summary


def add_summaries(data):
    return [{**row, SUMMARY_KEY: get_summary(row)} for row in data]


def read_cap_one_data(file):
    data = list(read_csv_data(file, filter=(lambda ln: len(ln) > 0)))
    for row in data:
        if row[MINUS_KEY] != '':
            row[MINUS_KEY] = "{:.2f}".format(-float(row[MINUS_KEY]))
    return data


def write_combined_csv_data(data, file):
    # Start with piecewise ascending order, so stable sorting keeps the order
    # XXX TODO
    # data = list(reversed(data))
    # ...then order by transaction date
    # data = sorted(data, key=lambda d: d['Transaction Date'])
    write_csv_data(data, file)


def write_collated(data, collation_key, file):
    cat_totals = {}
    for row in data:
        cat = row[collation_key]
        if cat not in cat_totals:
            cat_totals[cat] = [0, 0, 0]
        cat_totals[cat][0] += 1
        if row[MINUS_KEY] != '':
            cat_totals[cat][1] += float(row[MINUS_KEY])
        if row[PLUS_KEY] != '':
            cat_totals[cat][2] += float(row[PLUS_KEY])
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
    parser = argparse.ArgumentParser(description='Read Capital One CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_cap_one_data(f))
        # data = combine_data(data, add_source(read_cap_one_data(f), f))
    write_combined_csv_data(data, 'CapitalOne-combined.csv')
    data = add_summaries(data)
    write_collated(data, SUMMARY_KEY, 'CapitalOne-summary.csv')
    write_collated(data, CATEGORY_KEY, 'CapitalOne-summary-cat.csv')


if __name__ == '__main__':
    main()
