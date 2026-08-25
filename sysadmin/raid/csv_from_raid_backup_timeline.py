#!/usr/bin/python3
import argparse
import csv
import datetime as dt
import io
from pathlib import Path
import re
import sys

from estimate_raid_backup_timeline import (
    LogData,
    Action,
    read_logfile,
    get_actions,
    check_actions,
)


def print_csv(
    logs_data: list[LogData],
    actions: list[str],
    *,
    file: Path | str | io.TextIOBase = "timeline.csv",
    threshold: dt.timedelta = dt.timedelta(seconds=5),
) -> None:
    def find_action(log: LogData, action: str) -> Action | None:
        if not log.actions:
            return None
        match = [a for a in log.actions if a.text == action]
        assert len(match) <= 1, f"Multiple matches for {action!r} in {log.path!r}!?"
        if not match:
            return None
        return match[0]

    data: list[tuple[str, tuple[dt.timedelta | None, ...]]] = []
    for action in actions:
        matching = [find_action(log, action) for log in logs_data]
        durations = [a.duration if a else None for a in matching]
        if threshold is None or any((d and d >= threshold for d in durations)):
            data.append((action, tuple(durations)))

    def write_data(fio: io.TextIOBase) -> None:
        writer = csv.writer(fio, dialect=csv.excel)
        columns = [re.sub(r"^log\.", "", Path(log.path).stem) for log in logs_data]
        writer.writerow(["action", *columns])
        writer.writerows([(dd[0], *dd[1]) for dd in data])

    if isinstance(file, io.TextIOBase):
        write_data(file)
    else:
        with open(file, "w") as f:
            write_data(f)
        print(f"Wrote {file}")


def process_logfiles(settings: argparse.Namespace) -> None:
    logs = [read_logfile(f) for f in settings.logs]
    completed = [r for r in logs if r.completed]
    assert len(completed) > 0, "No completed logs found."
    actions = get_actions(completed[-1])
    for r in logs:
        check_actions(r, actions)
    print_csv(logs, actions)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read `raid-backup` logs and estimate backup completion."
    )
    parser.add_argument(
        "logs",
        nargs="+",
        metavar="LOG",
        help=("Log file(s) to read."),
    )
    settings = parser.parse_args()
    return settings


def main() -> None:
    settings = parse_args()
    process_logfiles(settings)


if __name__ == "__main__":
    main()
