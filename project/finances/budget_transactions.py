#!/not executable but recognized as/python3
import codecs
import csv
import enum


class Column(enum.StrEnum):
    DATE = enum.auto()
    POSTED_DATE = enum.auto()
    DEBIT = enum.auto()
    CREDIT = enum.auto()
    SOURCE = enum.auto()
    CATEGORY = enum.auto()
    DESCRIPTION = enum.auto()


# XXX TODO
# def add_source(data, source):
#     return [{**row, SOURCE_KEY: source} for row in data]

# XXX TODO
# def get_summary(row):
#     ...

# XXX TODO
# def add_summaries(data):
#     return [{**row, SUMMARY_KEY: get_summary(row)} for row in data]


def read_csv_data(file, remove_until=None, normalize=(lambda ln: ln.rstrip()),
                  filter=None):
    with codecs.open(file, "r", encoding='utf-8-sig') as csv_fh:
        lines = list(csv_fh)
    if remove_until is not None:
        while len(lines) > 0 and not remove_until(lines[0]):
            lines = lines[1:]
    if normalize is not None:
        lines = [normalize(ln) for ln in lines]
    if filter is not None:
        lines = [ln for ln in lines if filter(ln)]
    data = list(csv.DictReader(lines))
    assert all((d.keys() == data[0].keys() for d in data))
    return data


def write_csv_data(data, file):
    assert all((d.keys() == data[0].keys() for d in data))
    with codecs.open(file, "w", encoding='utf-8') as csv_fh:
        writer = csv.DictWriter(csv_fh, data[0].keys(), restval=None)
        writer.writeheader()
        for row in data:
            writer.writerow(row)


def combine_data(data0, data1):
    if data0 is None or len(data0) == 0:
        return data1
    elif data1 is None or len(data1) == 0:
        return data0
    assert data0[0].keys() == data1[0].keys()
    return [*data0, *data1]


# XXX TODO
# def write_collated(data, collation_key, file):
#     cat_totals = {}
#     for row in data:
#         cat = row[collation_key]
#         if cat not in cat_totals:
#             cat_totals[cat] = [0, 0, 0]
#         cat_totals[cat][0] += 1
#         if row[MINUS_KEY] != '':
#             cat_totals[cat][1] += float(row[MINUS_KEY])
#         if row[PLUS_KEY] != '':
#             cat_totals[cat][2] += float(row[PLUS_KEY])
#     cat_summary = []
#     for k in sorted(cat_totals.keys(), key=lambda x: -sum(cat_totals[x][1:3])):
#         instances = cat_totals[k][0]
#         val_minus = ("{:.2f}".format(cat_totals[k][1]) if cat_totals[k][1] != 0
#                      else '')
#         val_plus = ("{:.2f}".format(cat_totals[k][2]) if cat_totals[k][2] != 0
#                     else '')
#         # print(f"{instances:2d} {k:50.50s} {val_minus:>10.10s}"
#         #       f" {val_plus:>10.10s}")
#         cat_summary.append({'#': instances, SUMMARY_KEY: k,
#                             'Withdrawals': val_minus, 'Deposits': val_plus})
#     write_csv_data(cat_summary, file)
