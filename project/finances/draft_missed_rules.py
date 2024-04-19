#!/usr/bin/env -S python3 -B
import argparse
import re
import sys

from budget_transactions import read_csv_data, write_csv_data_to_handle, \
    Column, RuleColumn, Total


def escape_regex(text):
    return re.sub(r'(?<!\\)\\([- #&])', r'\1', re.escape(text))


def recapitalize(text):
    return re.sub(r"(\w+(?:'[Ss])?)", lambda m: m.group(1).capitalize(), text)


def prepare_category(text):
    return '?' + re.sub(r'\)$', '', re.sub(r'^\(', '', text))


def needs_manual_update(row):
    return (len(row[Column.CATEGORY]) == 0 or row[Column.CATEGORY][0] == '(')


def produce_rules(filename):
    print(f"Reading {filename}", file=sys.stderr)
    data_in = read_csv_data(filename, normalize=None)

    data_out = []
    for row_in in data_in:
        if not needs_manual_update(row_in):
            continue
        row_out = {
            RuleColumn.IN_DESCRIPTION: escape_regex(recapitalize(
                row_in[Column.DESCRIPTION])),
            RuleColumn.IN_CATEGORY: '',
            RuleColumn.IN_SOURCE: '',
        }
        if Column.DEBIT in row_in or Column.CREDIT in row_in:
            if Column.DEBIT in row_in and Column.CREDIT in row_in:
                amount = Total.parse(debit=row_in[Column.DEBIT],
                                     credit=row_in[Column.CREDIT])
            elif Column.DEBIT in row_in:
                amount = Total.parse(debit=row_in[Column.DEBIT])
            elif Column.CREDIT in row_in:
                amount = Total.parse(credit=row_in[Column.CREDIT])
            row_out = {
                **row_out,
                'total': amount.total.format(),
            }
        row_out = {
            **row_out,
            RuleColumn.OUT_DESCRIPTION: recapitalize(
                row_in[Column.DESCRIPTION]),
            RuleColumn.OUT_CATEGORY: prepare_category(row_in[Column.CATEGORY]),
            RuleColumn.OUT_SOURCE: '',
            RuleColumn.CONTINUE: '',
            'comments': 'original: ' + row_in[Column.DESCRIPTION],
        }
        data_out.append(row_out)

    write_csv_data_to_handle(data_out, sys.stdout)
    print("Wrote to stdout", file=sys.stderr)


def main():
    default_file = 'finances-summary-description+category.csv'
    parser = argparse.ArgumentParser(
        description='Read a desc+cat CSV and generate "missing" rules from it')
    parser.add_argument('FILE', nargs='?',
                        help=("A CSV file containing descriptions, categories"
                              " and possibly debits/credits."
                              f" [default: {default_file}]"),
                        default=default_file)
    opts = parser.parse_args()
    produce_rules(opts.FILE)


if __name__ == '__main__':
    main()
