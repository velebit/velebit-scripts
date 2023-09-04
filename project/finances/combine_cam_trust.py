#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data

DESCRIPTION_KEY = '<Description>'
ADDITIONAL_INFO_KEY = '<Additional Info>'
MINUS_KEY = '<Withdrawal Amount>'
PLUS_KEY = '<Deposit Amount>'
SUMMARY_KEY = 'Summary'


def get_summary(row):
    desc = row[DESCRIPTION_KEY]
    cat = row[ADDITIONAL_INFO_KEY]
    cat = regex.sub(r'^POS PURCHASE TERMINAL\s+\S+\s+(?:\d+\s+)?', '', cat)
    cat = regex.sub(r'^SURCHARGE AMOUNT TERMINAL\s+\S+\s+(?:\d+\s+)?',
                    'SURCHARGE ', cat)
    cat = regex.sub(r'^CASH WITHDRAWAL TERMINAL\s+\S+\s+(?:\d+\s+)?', '', cat)
    cat = regex.sub(r'^(CAPITAL ONE|COVIDIEN LP)\s.*', '\\1', cat)
    cat = regex.sub(r'\s+\#?(?<!\d)(?<!MY)\d.*', '', cat)
    cat = regex.sub(r'\s{2,}', ' ', cat)
    if cat == '' or regex.match(r'^ATM ', desc):
        return desc
    else:
        return desc + ": " + cat


def add_summaries(data):
    return [{**row, SUMMARY_KEY: get_summary(row)} for row in data]


def read_cam_trust_data(file):
    data = list(read_csv_data(file, filter=(lambda ln: len(ln) > 0)))
    return list(reversed(data))


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
    parser = argparse.ArgumentParser(description='Read Cambridge Trust CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_cam_trust_data(f))
    write_csv_data(data, 'CamTrust-combined.csv')
    data = add_summaries(data)
    write_collated(data, SUMMARY_KEY, 'CamTrust-summary.csv')


if __name__ == '__main__':
    main()
