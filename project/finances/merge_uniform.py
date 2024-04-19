#!/usr/bin/env -S python3 -B
import argparse

from budget_transactions import read_csv_data, combine_data, write_csv_data, \
    Column, Total


def read_uniform_data(file):
    reader = read_csv_data(file)
    return list(reader)


def summarize(data, summary_keys):
    key0, other_keys = summary_keys[0], tuple(summary_keys[1:])
    summary_tree = {}
    for row in data:
        value0 = row[key0]
        other_values = tuple((row[k] for k in other_keys))
        if value0 not in summary_tree.keys():
            summary_tree[value0] = {'total': Total(), 'num': 0,
                                    'subdivided': {}}
        if other_values not in summary_tree[value0]['subdivided'].keys():
            summary_tree[value0]['subdivided'][other_values] = \
                {'total': Total(), 'num': 0}
        this = Total.parse(debit=row[Column.DEBIT], credit=row[Column.CREDIT])
        summary_tree[value0]['total'] += this
        summary_tree[value0]['num'] += 1
        summary_tree[value0]['subdivided'][other_values]['total'] += this
        summary_tree[value0]['subdivided'][other_values]['num'] += 1
    summary = []
    for k0, v0 in sorted(summary_tree.items(),
                         key=lambda kv: kv[1]['total'].total):
        # for kX, vX in sorted(v0['subdivided'].items(), key=lambda kv: kv[0]):
        for kX, vX in sorted(v0['subdivided'].items(),
                             key=lambda kv: kv[1]['total'].total):
            summary.append({key0: k0,
                            **dict(zip(other_keys, kX)),
                            Column.NUMBER: '{:d}'.format(vX['num']),
                            Column.DEBIT: vX['total'].debit.format(),
                            Column.CREDIT: vX['total'].credit.format(),
                            })
    return summary


def main():
    parser = argparse.ArgumentParser(description='Merge uniform CSV')
    parser.add_argument('FILE', nargs='*', help='CSV file(s)')
    opts = parser.parse_args()
    data = None
    for f in opts.FILE:
        data = combine_data(data, read_uniform_data(f))
    data = sorted(data, key=lambda d: d[Column.DATE])
    write_csv_data(data, 'finances-all.csv')
    write_csv_data(summarize(data, (Column.CATEGORY, Column.DESCRIPTION,
                                    Column.SOURCE)),
                   'finances-summary-category+description+source.csv')
    write_csv_data(summarize(data, (Column.DESCRIPTION, Column.CATEGORY)),
                   'finances-summary-description+category.csv')
    write_csv_data(summarize(data, (Column.CATEGORY,)),
                   'finances-summary-category.csv')


if __name__ == '__main__':
    main()
