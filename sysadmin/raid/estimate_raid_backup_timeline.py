#!/usr/bin/python3
import argparse
import datetime as dt
import re
from dataclasses import dataclass


@dataclass
class Action:
    text: str
    begin: dt.datetime
    end: dt.datetime | None = None
    duration: dt.timedelta | None = None


@dataclass
class LogData:
    path: str
    actions: list[Action] | None = None
    begin: dt.datetime | None = None
    end: dt.datetime | None = None
    completed: bool | None = None


@dataclass
class CollatedTime:
    text: str
    sorted_durations: list[dt.timedelta]

    @property
    def duration_min(self) -> dt.timedelta:
        assert len(self.sorted_durations) > 0
        return self.sorted_durations[0]

    @property
    def duration_max(self) -> dt.timedelta:
        assert len(self.sorted_durations) > 0
        return self.sorted_durations[-1]


def strip_color(text: str) -> str:
    return re.sub(r"\033\[\d+(?:;\d+)*m", "", text)


def read_logfile(path: str) -> LogData:
    log_data = LogData(path=path)
    completed = False
    last_time: dt.datetime | None = None
    with open(path, "r") as f:
        time_data: list[Action] = []
        for line in f:
            line = strip_color(line.rstrip())
            if not re.search(r"^-- ", line):
                continue
            match = re.search(
                r"^-- \[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] -- (.*)$", line
            )
            assert match, f"Unexpected line format: {line}"
            time = dt.datetime.strptime(match.group(1), "%Y-%m-%d %H:%M:%S")
            text = match.group(2).strip()
            text = re.sub(r"/media/\w+/backup(?:_\w+)?/", r"{backup}/", text)
            if re.search(r"^(?:Backing up|Cleaning up)", text):
                assert len(time_data) == 0 or time_data[-1].end is not None
                time_data.append(Action(text=text, begin=time))
            else:
                if len(time_data) > 0 and time_data[-1].end is None:
                    time_data[-1].end = time
                    time_data[-1].duration = time_data[-1].end - time_data[-1].begin
                if re.search(r"disk margin", text):
                    completed = True
                last_time = time
        if completed:
            assert (
                len(time_data) == 0 or time_data[-1].end is not None
            ), f"No end time for path {path}"
        if len(time_data) == 0:
            log_data.actions = None
            log_data.begin = None
            log_data.end = None
            log_data.completed = None
        else:
            log_data.actions = time_data
            log_data.begin = time_data[0].begin
            if not completed or last_time is None:
                log_data.end = None
                log_data.completed = False
            else:
                log_data.end = last_time
                log_data.completed = True
    return log_data


def get_actions(log_data: LogData) -> list[str]:
    if log_data.actions is None:
        return []
    else:
        return [a.text for a in log_data.actions]


def check_actions(log_data: LogData, actions: list[str]) -> None:
    log_actions = get_actions(log_data)
    for a in actions:
        if a not in log_actions:
            print(f"{log_data.path}: Missing action {a!r}")
    for a in log_actions:
        if a not in actions:
            print(f"{log_data.path}: Unexpected action {a!r}")


def collate_times(
    past_logs_data: list[LogData], actions: list[str]
) -> list[CollatedTime]:
    collated: list[CollatedTime] = []
    for action in actions:
        matching = [
            a
            for log_data in past_logs_data
            if log_data.actions
            for a in log_data.actions
            if a.text == action
        ]
        durations = [a.duration for a in matching if a.duration is not None]
        assert durations, "No matching durations (!?)"
        collated.append(CollatedTime(text=action, sorted_durations=sorted(durations)))
    return collated


def calculate_percentile(
    duration: dt.timedelta, collated_time: CollatedTime
) -> float | None:
    durations = collated_time.sorted_durations
    num_samples = len(durations)
    if num_samples < 2 or durations[-1] < dt.timedelta(minutes=1):
        return None
    percents = [100.0 * i / (num_samples - 1) for i in range(num_samples)]
    assert len(percents) == num_samples
    indices_matching = [i for i in range(num_samples) if durations[i] == duration]
    if indices_matching:
        result = (percents[indices_matching[0]] + percents[indices_matching[-1]]) / 2
        return result
    indices_before = [i for i in range(num_samples) if durations[i] < duration]
    indices_after = [i for i in range(num_samples) if durations[i] > duration]
    assert (len(indices_before) + len(indices_after)) == num_samples
    EPSILON = dt.timedelta(seconds=1e-6)
    if len(indices_before) == 0:
        index0, index1 = indices_after[0], indices_after[1]
        assert (index1 - index0) == 1
        # if would divide by 0, try finding a better span
        if (durations[index1] - durations[index0]) < EPSILON:
            better_indices = [
                i
                for i in indices_after
                if durations[i] >= (durations[index0] + EPSILON)
            ]
            if len(better_indices) > 0:
                index1 = better_indices[0]
                assert (index1 - index0) > 1
        duration0, duration1 = durations[index0], durations[index1]
        duration_delta = max((duration1 - duration0, EPSILON))  # avoid division by 0
    elif len(indices_after) == 0:
        index0, index1 = indices_before[-2], indices_before[-1]
        assert (index1 - index0) == 1
        # if would divide by 0, try finding a better span
        if (durations[index1] - durations[index0]) < EPSILON:
            better_indices = [
                i
                for i in indices_before
                if durations[i] <= (durations[index1] - EPSILON)
            ]
            if len(better_indices) > 0:
                index0 = better_indices[-1]
                assert (index1 - index0) > 1
        duration0, duration1 = durations[index0], durations[index1]
        duration_delta = max((duration1 - duration0, EPSILON))  # avoid division by 0
    else:
        index0, index1 = indices_before[-1], indices_after[0]
        assert (index1 - index0) == 1
        duration0, duration1 = durations[index0], durations[index1]
        duration_delta = duration1 - duration0
        assert duration_delta > dt.timedelta(seconds=0)
    ratio = (duration - duration0) / duration_delta
    percent0, percent1 = percents[index0], percents[index1]
    result = percent0 + ratio * (percent1 - percent0)
    return result


def percentile_text(percent: float | None, prefix: str = "", suffix: str = "") -> str:
    if percent is None:
        return ""
    if percent < 0:
        return f"{prefix}<0{suffix}"
    if percent > 100:
        return f"{prefix}>100{suffix}"
    return f"{prefix}{percent:.0f}{suffix}"


def percentile_bar_graph(
    percent: float | None, prefix: str = "", suffix: str = "", width: int = 11
) -> str:
    if percent is None:
        return ""
    assert width >= 2
    disp = ["|", *(["-"] * (width - 2)), "|"]
    if percent < 0:
        disp[0] = "<"
    elif percent > 100:
        disp[-1] = ">"
    else:
        pos = round(percent * (width - 1) / 100)
        assert 0 <= pos <= width
        disp[pos] = "*"
    return prefix + "".join(disp) + suffix


def print_estimate(
    active_log_data: LogData,
    collated_times: list[CollatedTime],
    percent_as_text: bool = False,
) -> None:
    # first, print data for already completed and started actions
    if active_log_data.actions:
        assert active_log_data.begin is not None
        next_start_min, next_start_max = (active_log_data.begin,) * 2
        begin = next_start_min.strftime("%H:%M:%S")
        range = f"{begin}:"
        print(f"{'started':<10s} {range:<20s} (backup started)")
        for a in active_log_data.actions:
            matching_times = [c for c in collated_times if c.text == a.text]
            assert len(matching_times) == 1
            if a.duration is not None:
                assert a.end is not None
                end = a.end.strftime("%H:%M:%S")
                pct_value = calculate_percentile(a.duration, matching_times[0])
                if percent_as_text:
                    percent = percentile_text(
                        pct_value,
                        prefix="(",
                        suffix="%ile)",
                    )
                else:
                    percent = percentile_bar_graph(pct_value, width=9)
                range = f"{end + ':':<9s}{percent:>11s}"
                print(f"{'ended':<10s} {range:<20s} {a.text}")
                next_start_min, next_start_max = (a.end,) * 2
            else:
                # started but not completed
                end_min = a.begin + matching_times[0].duration_min
                end_max = a.begin + matching_times[0].duration_max
                # if we're already past the expected time, adjust it
                now = dt.datetime.now()
                end_min, end_max = tuple(max((e, now)) for e in (end_min, end_max))
                end0, end1 = [t.strftime("%H:%M:%S") for t in (end_min, end_max)]
                if end_max > end_min:
                    range = f"{end0} - {end1}:"
                else:
                    range = f"{end0}:"
                print(f"{'expected':<10s} {range:<20s} {a.text}")
                next_start_min, next_start_max = end_min, end_max
            collated_times = [c for c in collated_times if c.text != a.text]
    else:
        next_start_min, next_start_max = (dt.datetime.now(),) * 2  # fallback if no data
        begin = next_start_min.strftime("%H:%M:%S")
        range = f"{begin}:"
        print(f"{'starting':<10s} {range:<20s} (assumed start time)")

    # print data for remaining expected actions
    for c in collated_times:
        end_min = next_start_min + c.duration_min
        end_max = next_start_max + c.duration_max
        end0, end1 = [t.strftime("%H:%M:%S") for t in (end_min, end_max)]
        if end_max > end_min:
            range = f"{end0} - {end1}:"
        else:
            range = f"{end0}:"
        print(f"{'expected':<10s} {range:<20s} {c.text}")
        next_start_min, next_start_max = end_min, end_max


def process_logfiles(settings: argparse.Namespace) -> None:
    references = [read_logfile(f) for f in settings.reference_logs]
    for r in references:
        if not r.completed:
            print(f"Warning: reference log {r.path} has not completed," " skipping.")
    references = [r for r in references if r.completed]
    assert len(references) > 0, "No valid reference logs left."
    actions = get_actions(references[-1])
    for r in references:
        check_actions(r, actions)
    history = collate_times(references, actions)
    active = read_logfile(settings.active_log)
    if active.completed:
        end_time = active.end
        assert end_time is not None
        end = end_time.strftime("%H:%M:%S")
        print(
            f"Warning: supposedly active log {active.path}" f" has completed at {end}!"
        )
    print_estimate(active, history, percent_as_text=settings.percent)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read `raid-backup` logs and estimate backup completion."
    )
    parser.add_argument(
        "--percent",
        help=(
            "Display the percentile of the completed portions of the active run"
            " among all runs as a number, instead of a text graph."
        ),
    )
    parser.add_argument(
        "reference_logs",
        nargs="+",
        metavar="REFERENCE_LOG",
        help=("Log file(s) to read to deduce the order and timing."),
    )
    parser.add_argument(
        "active_log", metavar="ACTIVE_LOG", help="Log file for the in-progress backup."
    )
    settings = parser.parse_args()
    return settings


def main() -> None:
    settings = parse_args()
    process_logfiles(settings)


if __name__ == "__main__":
    main()
