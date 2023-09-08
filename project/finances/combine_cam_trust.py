#!/usr/bin/env -S python3 -B
import argparse
import regex

from budget_transactions import read_csv_data, combine_data, write_csv_data, \
    Column

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
    info = regex.sub(r'\s+\#?(?<!\d)(?<!MY)\d.*', '', info)
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
        Column.DATE: row[SRC_KEY_DATE],
        Column.POSTED_DATE: row[SRC_KEY_DATE],
        Column.DEBIT: row[SRC_KEY_DEBIT],
        Column.CREDIT: row[SRC_KEY_CREDIT],
        Column.SOURCE: get_source(row),
        Column.CATEGORY: '',
        Column.DESCRIPTION: get_description(row),
    }
    return info


def make_uniform(data):
    return [make_uniform_row(row) for row in data]


# XXX TODO
def write_collated(data, collation_key, file):
    cat_totals = {}
    for row in data:
        cat = row[collation_key]
        if cat not in cat_totals:
            cat_totals[cat] = [0, 0, 0]
        cat_totals[cat][0] += 1
        if row[Column.DEBIT] != '':
            cat_totals[cat][1] += float(row[Column.DEBIT])
        if row[Column.CREDIT] != '':
            cat_totals[cat][2] += float(row[Column.CREDIT])
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
    parser = argparse.ArgumentParser(description='Read Cambridge Trust CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_cam_trust_data(f))
    data = sorted(data, key=lambda d: d[SRC_KEY_DATE])
    write_csv_data(data, 'CamTrust-combined.csv')
    data = make_uniform(data)
    write_csv_data(data, 'CamTrust-uniform.csv')
    # XXX TODO
    # data = add_summaries(data)
    # write_collated(data, SUMMARY_KEY, 'CamTrust-summary.csv')


if __name__ == '__main__':
    main()
