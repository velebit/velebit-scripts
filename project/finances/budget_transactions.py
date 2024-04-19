#!/not executable but recognized as/python3
import codecs
import csv
import dateutil.parser
import enum
import functools
import re


class Column(enum.StrEnum):
    DATE = enum.auto()
    POSTED_DATE = enum.auto()
    DEBIT = enum.auto()
    CREDIT = enum.auto()
    SOURCE = enum.auto()
    CATEGORY = enum.auto()
    DESCRIPTION = enum.auto()
    COMMENT = enum.auto()
    NUMBER = '#'


class RulePrefix(enum.StrEnum):
    IN = 'in:'
    OUT = 'out:'


class RuleColumn(enum.StrEnum):
    IN_SOURCE = RulePrefix.IN + Column.SOURCE
    IN_CATEGORY = RulePrefix.IN + Column.CATEGORY
    IN_DESCRIPTION = RulePrefix.IN + Column.DESCRIPTION
    OUT_SOURCE = RulePrefix.OUT + Column.SOURCE
    OUT_CATEGORY = RulePrefix.OUT + Column.CATEGORY
    OUT_DESCRIPTION = RulePrefix.OUT + Column.DESCRIPTION
    CONTINUE = enum.auto()


def is_string_false(text):
    return text in ('', '0', 'n', 'N', 'no', 'No', 'NO')


def is_string_true(text):
    return not is_string_false(text)


@functools.total_ordering
class Date(object):
    def __init__(self, date):
        self.date = date

    @classmethod
    def parse(cls, date_str):
        return cls(dateutil.parser.parse(date_str).date())

    def format(self, date_format="%Y-%m-%d"):
        return self.date.strftime(date_format)

    def __eq__(self, other):
        return self.date == other.date

    def __lt__(self, other):
        return self.date < other.date


@functools.total_ordering
class Money(object):
    def __init__(self, amount=None):
        self.amount = amount

    @classmethod
    def parse(cls, amount_str):
        if amount_str is None or amount_str == '':
            return cls(None)
        else:
            return cls(
                float(re.sub(r',', '', re.sub(r' *\$', '', amount_str))))

    def format(self):
        if self.amount is None:
            return ''
        else:
            return "{:.2f}".format(self.amount)

    @classmethod
    def reformat(cls, amount_str):
        return cls.parse(amount_str).format()

    def __str__(self):
        return self.format()

    def __eq__(self, other):
        return self.amount == other.amount

    def __lt__(self, other):
        return (self.amount or -1e-9) < (other.amount or -1e-9)

    def clone(self):
        return self.__class__(self.amount)

    def __iadd__(self, other):
        if self.amount is None:
            self.amount = other.amount
        elif other.amount is not None:
            self.amount += other.amount
        return self

    def __isub__(self, other):
        if self.amount is None:
            self.amount = -other.amount
        elif other.amount is not None:
            self.amount -= other.amount
        return self

    def __add__(self, other):
        return self.clone().__iadd__(other)

    def __sub__(self, other):
        return self.clone().__isub__(other)

    def __neg__(self):
        if self.amount is None:
            return self
        else:
            return self.__class__(-self.amount)

    def if_positive(self):
        if self.amount is not None and self.amount > 0:
            return self
        else:
            return self.__class__(None)

    def if_negative(self):
        if self.amount is not None and self.amount < 0:
            return self
        else:
            return self.__class__(None)


class Total(object):
    def __init__(self, *, debit=None, credit=None):
        if debit is not None:
            self.debit = debit
        else:
            self.debit = Money()
        if credit is not None:
            self.credit = credit
        else:
            self.credit = Money()

    @classmethod
    def parse(cls, *, debit=None, credit=None):
        return cls(debit=Money.parse(debit), credit=Money.parse(credit))

    @property
    def total(self):
        return self.debit + self.credit

    def clone(self):
        return self.__class__(debit=self.debit.clone(),
                              credit=self.credit.clone())

    def __iadd__(self, other):
        self.debit += other.debit
        self.credit += other.credit
        return self

    def __isub__(self, other):
        self.debit -= other.debit
        self.credit -= other.credit
        return self

    def __add__(self, other):
        return self.clone().__iadd__(other)

    def __sub__(self, other):
        return self.clone().__isub__(other)

    def __neg__(self):
        return self.__class__(debit=-self.debit,
                              credit=-self.credit)


def read_csv_data_from_lines(lines, remove_until=None,
                             normalize=(lambda ln: ln.rstrip()), filter=None):
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


def read_csv_data(file, remove_until=None, normalize=(lambda ln: ln.rstrip()),
                  filter=None):
    with codecs.open(file, "r", encoding='utf-8-sig') as csv_fh:
        lines = list(csv_fh)
    return read_csv_data_from_lines(lines, remove_until=remove_until,
                                    normalize=normalize, filter=filter)


def write_csv_data_to_handle(data, csv_fh):
    assert all((d.keys() == data[0].keys() for d in data))
    writer = csv.DictWriter(csv_fh, data[0].keys(), restval=None)
    writer.writeheader()
    for row in data:
        writer.writerow(row)


def write_csv_data(data, file):
    assert all((d.keys() == data[0].keys() for d in data))  # before creating!
    with codecs.open(file, "w", encoding='utf-8') as csv_fh:
        write_csv_data_to_handle(data, csv_fh)


def combine_data(data0, data1):
    if data0 is None or len(data0) == 0:
        return data1
    elif data1 is None or len(data1) == 0:
        return data0
    assert data0[0].keys() == data1[0].keys()
    return [*data0, *data1]


class RemappingRules(object):
    def __init__(self, filename):
        self.filename = filename
        self.transforms = read_csv_data(filename)

    def _tf_matches(self, tf, row):
        if tf[RuleColumn.IN_SOURCE] != '':
            if not re.search(tf[RuleColumn.IN_SOURCE],
                             row[Column.SOURCE], re.IGNORECASE):
                return False
        if tf[RuleColumn.IN_CATEGORY] != '':
            if not re.search(tf[RuleColumn.IN_CATEGORY],
                             row[Column.CATEGORY], re.IGNORECASE):
                return False
        if tf[RuleColumn.IN_DESCRIPTION] != '':
            if not re.search(tf[RuleColumn.IN_DESCRIPTION],
                             row[Column.DESCRIPTION], re.IGNORECASE):
                return False
        return True

    def _tf_apply(self, tf, row):
        out = dict(row)  # make a copy
        if tf[RuleColumn.OUT_SOURCE] != '':
            out[Column.SOURCE] = tf[RuleColumn.OUT_SOURCE]
        if tf[RuleColumn.OUT_CATEGORY] != '':
            out[Column.CATEGORY] = tf[RuleColumn.OUT_CATEGORY]
        if tf[RuleColumn.OUT_DESCRIPTION] != '':
            out[Column.DESCRIPTION] = tf[RuleColumn.OUT_DESCRIPTION]
        return out

    def _transform_row(self, row):
        for tf in self.transforms:
            if self._tf_matches(tf, row):
                row = self._tf_apply(tf, row)
                if is_string_false(tf[RuleColumn.CONTINUE]):
                    return row
        return row

    def transform(self, data):
        return [self._transform_row(row) for row in data]


g_remapping = None


def apply_remapping(data):
    global g_remapping
    if g_remapping is None:
        g_remapping = RemappingRules('remapping_rules.csv')
        assert g_remapping is not None
    return g_remapping.transform(data)
