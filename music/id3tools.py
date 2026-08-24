"""Utilities for inspecting and manipulating ID3 tags."""

import os
from pathlib import Path
import re
import shutil
import struct
import sys
from typing import Any, Callable, Generator, Iterable, TypeVar, cast

import eyed3
import eyed3.core
import eyed3.id3
import eyed3.id3.frames
import unidecode

T = TypeVar("T")


def quote_chars(text: str) -> str:
    """Quote control characters while leaving ordinary Unicode readable."""
    # Use repr() to quote newlines, tabs, and other weird characters.
    # Do not use ascii(), because we want to allow non-ASCII in general (č, ñ).
    text = repr(str(text))
    # Remove outer quotes and inner \" \' \\ escapes added by repr()
    assert len(text) > 0
    assert text[0] in ("'", '"') and text[-1] == text[0]
    return re.sub(r"\\(\W)", r"\1", text[1:-1])


def text(
    iterable: Iterable[str], *, as_ascii: bool = False, raw: bool = False
) -> Iterable[str]:
    """Format text values as ASCII or quoted strings."""
    if as_ascii:
        iterable = (unidecode.unidecode(s) for s in iterable)
    if not raw:
        iterable = (quote_chars(s) for s in iterable)
    return iterable


def uniq(iterable: Iterable[T]) -> Generator[T]:
    """Yield each value from an iterable once, in first-seen order."""
    seen: set[T] = set()
    for element in iterable:
        if element not in seen:
            seen.add(element)
            yield element


def get_description(fid: bytes) -> str:
    """Return the known description for an ID3 frame identifier."""
    try:
        value = eyed3.id3.frames.ID3_FRAMES[fid][0]
        assert isinstance(value, str)
        return value
    except KeyError:
        pass
    try:
        value = eyed3.id3.frames.NONSTANDARD_ID3_FRAMES[fid][0]
        assert isinstance(value, str)
        return value
    except (KeyError, AttributeError):
        pass
    try:
        alt = eyed3.id3.frames.TAGS2_2_TO_TAGS_2_3_AND_4[fid]
        if alt != fid:
            return get_description(alt)
    except (KeyError, AttributeError):
        pass
    return "?"


ENCODING_NAME_LATIN1 = "latin1"
ENCODING_NAME_UTF_16 = "UTF-16"
ENCODING_NAME_UTF_16BE = "UTF-16-big-endian"
ENCODING_NAME_UTF_8 = "UTF-8"


def encoding_name(encoding: bytes) -> str:
    """Convert an eyeD3 text-encoding marker to a readable name."""
    if encoding == eyed3.id3.LATIN1_ENCODING:
        return ENCODING_NAME_LATIN1
    elif encoding == eyed3.id3.UTF_16_ENCODING:
        return ENCODING_NAME_UTF_16
    elif encoding == eyed3.id3.UTF_16BE_ENCODING:
        return ENCODING_NAME_UTF_16BE
    elif encoding == eyed3.id3.UTF_8_ENCODING:
        return ENCODING_NAME_UTF_8
    else:
        return "encoding " + " ".join(("x%02X" % b) for b in encoding)


def encoding_code(name: str) -> bytes:
    """Convert a supported readable encoding name to its eyeD3 marker."""
    if name == ENCODING_NAME_LATIN1:
        return eyed3.id3.LATIN1_ENCODING
    elif name == ENCODING_NAME_UTF_16:
        return eyed3.id3.UTF_16_ENCODING
    elif name == ENCODING_NAME_UTF_16BE:
        return eyed3.id3.UTF_16BE_ENCODING
    elif name == ENCODING_NAME_UTF_8:
        return eyed3.id3.UTF_8_ENCODING
    else:
        raise ValueError(f"Unknown encoding name '{name}'")


def get_frame_summary_key_value(info: dict[str, Any]) -> tuple[str | None, str, bool]:
    """Choose the display key, value, and value flag for a frame summary."""
    if "text" in info:
        return (info.get("description", None), info["text"], True)
    if "url" in info:
        return (info.get("description", None), info["url"], True)
    if "owner_id" in info and "uniq_id" in info:
        return (info["owner_id"], info["uniq_id"], True)
    if "owner_id" in info and "owner_data" in info:
        if (
            info["owner_id"] == "PeakValue" or info["owner_id"] == "AverageLevel"
        ) and len(info["owner_data"]) == 4:
            data = cast(int, struct.unpack("<i", info["owner_data"]))
            return (
                info["owner_id"],
                f"{data:d}",
                True,
            )
        else:
            return (info["owner_id"], ("(%d byte(s))" % len(info["owner_data"])), False)
    if "image_data" in info:
        return (None, ("(%d image byte(s))" % len(info["image_data"])), False)
    if "data" in info:
        return (None, ("(%d raw byte(s))" % len(info["data"])), False)
    return (None, "(exists)", False)


def get_frame_summary(
    frame: eyed3.id3.frames.Frame, *, as_ascii: bool = False, raw: bool = False
) -> dict[str, Any]:
    """Return display metadata and selected raw fields for one ID3 frame."""
    fid = cast(bytes, frame.id)
    summary: dict[str, str | eyed3.id3.frames.Frame] = {
        "id": fid.decode("ASCII"),
        "id_description": get_description(fid),
        "frame": frame,
    }

    def _fget(key: str) -> Any:
        return getattr(frame, key, None)

    def _copy(fkey: str, skey: str | None = None) -> None:
        value = _fget(fkey)
        if value is not None:
            summary[skey if skey is not None else fkey] = value

    _copy("text")
    _copy("description")
    _copy("url")
    _copy("user_url")
    _copy("owner_id")
    _copy("uniq_id")
    _copy("owner_data")
    _copy("image_data")
    _copy("data")

    raw_encoding = _fget("encoding")
    if raw_encoding is not None:
        summary["raw_encoding"] = raw_encoding
        summary["encoding"] = encoding_name(raw_encoding)

    language = _fget("lang")
    if language is not None:
        summary["language"] = language.decode("ASCII")

    _copy("date")  # a date representation of frame.text
    _copy("mime_type")
    _copy("picture_type")
    _copy("filename")
    _copy("toc")
    _copy("rating")
    _copy("email")
    _copy("count")
    _copy("title")
    _copy("subtitle")

    key, value, is_real_value = get_frame_summary_key_value(summary)
    if key is not None:
        (key,) = text((key,), as_ascii=as_ascii, raw=raw)
    (value,) = text((value,), as_ascii=as_ascii, raw=raw)

    if key is not None:
        summary["key"] = key
    if is_real_value:
        summary["value"] = value
    if key is None:
        summary["pretty"] = value
    else:
        summary["pretty"] = "[%s] %s" % (key, value)

    return summary


def frame_props(
    tag: eyed3.core.Tag, *, as_ascii: bool = False, raw: bool = False
) -> tuple[dict[str, Any], ...]:
    """Return summaries for all frames in an ID3 tag."""
    fs: eyed3.id3.frames.FrameSet = getattr(tag, "frame_set")
    frames = cast(tuple[eyed3.id3.frames.Frame, ...], tuple(fs.getAllFrames()))
    return tuple(
        get_frame_summary(frame, as_ascii=as_ascii, raw=raw) for frame in frames
    )


def abstract_props(
    tag: eyed3.core.Tag, *, as_ascii: bool = False, raw: bool = False
) -> tuple[dict[str, str | int], ...]:
    """Return commonly used, human-readable properties from an ID3 tag."""

    def _tget(key: str, index: int | None = None) -> str | int | None:
        value = getattr(tag, key, None)
        if value is not None and index is not None:
            value = value[index]
        return value

    props: tuple[dict[str, str | int | None], ...] = (
        {"id": "title", "id_description": "Track title", "value": _tget("title")},
        {"id": "artist", "id_description": "Track artist", "value": _tget("artist")},
        {
            "id": "album_artist",
            "id_description": "Album artist",
            "value": _tget("album_artist"),
        },
        {"id": "album", "id_description": "Album title", "value": _tget("album")},
        {
            "id": "track_num",
            "id_description": "Track number",
            "value": _tget("track_num", 0),
        },
        {
            "id": "num_tracks",
            "id_description": "Number of tracks in album",
            "value": _tget("track_num", 1),
        },
    )
    clean_props: tuple[dict[str, str | int], ...] = tuple(
        cast(dict[str, str | int], p)
        for p in props
        if not any(v is None for v in p.values())
    )
    for p in clean_props:
        if isinstance(p["value"], str):
            (p["value"],) = text((p["value"],), as_ascii=as_ascii, raw=raw)
        p["pretty"] = str(p["value"])
    return clean_props


def abstract_props_map(
    tag: eyed3.core.Tag, *, as_ascii: bool = False, raw: bool = False
) -> dict[str, dict[str, str | int]]:
    """Return common ID3 properties indexed by their property identifiers."""
    return {
        cast(str, f["id"]): f for f in abstract_props(tag, as_ascii=as_ascii, raw=raw)
    }


def all_props(
    tag: eyed3.core.Tag, *, as_ascii: bool = False, raw: bool = False
) -> tuple[dict[str, Any], ...]:
    """Return both frame-level and common properties from an ID3 tag."""
    fp = frame_props(tag, as_ascii=as_ascii, raw=raw)
    ap = abstract_props(tag, as_ascii=as_ascii, raw=raw)
    return (*fp, *ap)


def key_info(props: Iterable[dict[str, Any]]) -> tuple[dict[str, Any], ...]:
    """Return unique property identifiers and their descriptions."""
    return tuple(
        {"id": x[0], "id_description": x[1]}
        for x in uniq((y["id"], y["id_description"]) for y in props)
    )


def wipe_file(file: Path | str) -> None:
    """Remove every ID3 tag from a file."""
    eyed3.id3.tag.Tag.remove(file, version=eyed3.id3.ID3_ANY_VERSION)


def get_valid_id3_tag(file: str) -> eyed3.core.Tag | None:
    """Load and return a file's ID3 tag, reporting missing data to stderr."""
    id3file = eyed3.load(file)
    if not id3file:
        print(f"Could not load {file}!", file=sys.stderr)
        return None
    if not id3file.tag:
        print(f"No ID3 tag data in {file}!", file=sys.stderr)
        return None
    tag = id3file.tag
    assert isinstance(tag, eyed3.core.Tag)
    assert isinstance(tag, eyed3.id3.tag.Tag)
    return tag


def copy_id3(src_path: Path | str, dst_path: Path | str) -> None:
    """Copy the source tag to the destination while retaining its version."""
    file_src = eyed3.load(src_path)
    assert file_src, f"Could not load source {src_path!r}"
    if not file_src.tag:
        wipe_file(dst_path)
        return
    file_dst = eyed3.load(dst_path)
    assert file_dst, f"Could not load destination {dst_path!r}"
    assert file_src.tag.frame_set is not None
    assert isinstance(file_src.tag.frame_set, eyed3.id3.frames.FrameSet)
    file_dst.tag.frame_set = file_src.tag.frame_set
    # Use the old version, instead of hardcoding eyed3.id3.ID3_V2_3
    file_dst.tag.save(version=file_src.tag.version)


def remove_frame_from_frameset(
    frame_set: eyed3.id3.frames.FrameSet, frame: eyed3.id3.frames.Frame
) -> None:
    """Remove one frame and delete its empty frame-ID entry."""
    frame_list = frame_set[frame.id]
    frame_list.remove(frame)  # error if missing
    if len(frame_list) == 0:
        del frame_set[frame.id]  # error if missing


def remove_frames_from_file(
    file: Path | str,
    condition: Callable[[eyed3.id3.frames.Frame], bool],
    *,
    restore_file_time: bool = False,
) -> None:
    """Remove frames matching a predicate and optionally restore file times."""
    orig_stat = os.stat(file)
    id3file = eyed3.load(file)
    if not id3file:
        print(f"Could not load {file}!", file=sys.stderr)
        return
    if not id3file.tag:
        return
    assert id3file.tag
    fs = cast(eyed3.id3.frames.FrameSet, id3file.tag.frame_set)
    frames = cast(tuple[eyed3.id3.frames.Frame, ...], tuple(fs.getAllFrames()))
    for f in frames:
        if condition(f):
            remove_frame_from_frameset(fs, f)
    id3file.tag.save()
    if restore_file_time:
        os.utime(file, ns=(orig_stat.st_atime_ns, orig_stat.st_mtime_ns))


def make_backup(file: str, *, revert: bool = True, quiet: bool = False) -> None:
    """Replace a file with a copy while retaining its original as a .bak file."""
    backup = file + ".bak"
    try:
        os.unlink(backup)
    except FileNotFoundError:
        pass  # if unlink fails b/c no old backup file, that's OK
    os.replace(file, backup)  # if can't rename, exception has filenames
    try:
        shutil.copy2(backup, file, follow_symlinks=True)
    except Exception:
        if revert:  # on failed copy, try undoing the previous rename
            try:
                os.replace(backup, file)
            except OSError as e:
                if not quiet:
                    print(
                        f"While reverting '{backup}' -> '{file}': {e!r}",
                        file=sys.stderr,
                    )
                pass  # ignore error in inner rename
        raise  # propagate error in copy


"""
latinCharacterCodes =
  ( *range(0x20, 0x7E+1),
    # Croatian:
    0x0106, 0x0107, 0x010C, 0x010D, 0x0110, 0x0111, 0x0160, 0x0161,
    0x017D, 0x017E,
    # French etc:
    0x00C0, 0x00E0, 0x00C1, 0x00E1, 0x00C8, 0x00E8, 0x00C9, 0x00E9,
    0x00CA, 0x00EA, 0x00CB, 0x00EB, 0x00CE, 0x00EE, 0x00D3, 0x00F3,
    0x00DA, 0x00FA,
    # Spanish:
    0x00D1, 0x00F1,
    # German:
    0x00DF,           # eszett (lowercase only)
    # punctuation:
    0x00AB, 0x00BB,   # guillemets (French double_angle quotes)
    0x00A1, 0x00BF,   # inverted exclamation and question mark
    0x2018, 0x2019,   # single quotation marks (R "preferred" for apostrophe)
    0x201C, 0x201D,   # double quotation marks
    0x2013, 0x2014,   # en dash and em dash
    0x2026,           # ellipsis
  )
"""
