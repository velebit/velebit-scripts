#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data

DATE_KEY = 'Datetime'
FROM_KEY = 'From'
TO_KEY = 'To'
CATEGORY_KEY = 'Who'
AMOUNT_KEY = 'Amount (total)'
SUMMARY_KEY = 'Summary'


def read_venmo_data(file):
    reader = read_csv_data(file, remove_until=(lambda ln:
                                               regex.search(DATE_KEY, ln)))
    return [row for row in reader if row[DATE_KEY] != '']


def write_collated(data, collation_keys, file):
    cat_totals = {}
    for row in data:
        cat = None
        # Venmo swaps TO and FROM based on who made the request.
        # We pick not-Dvornik
        for k in collation_keys:
            if not regex.search(r'Dvornik', row[k]):
                cat = row[k]
                break
        if cat not in cat_totals:
            cat_totals[cat] = [0, 0, 0]
        cat_totals[cat][0] += 1
        amount = float(regex.sub(r',', '',
                                 regex.sub(r'\s*\$', '', row[AMOUNT_KEY])))
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
                            'Sent': val_minus, 'Received': val_plus})
    write_csv_data(cat_summary, file)


def main():
    parser = argparse.ArgumentParser(description='Read Venmo CSV')
    # 'Venmo-combined.csv'
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_venmo_data(f))
    write_csv_data(data, 'Venmo-combined.csv')
    write_collated(data, (TO_KEY, FROM_KEY), 'Venmo-summary.csv')


if __name__ == '__main__':
    main()
