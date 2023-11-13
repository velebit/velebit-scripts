# Utility code for ID3 manipulation

import eyed3.id3
import os
import re
import shutil
import struct
import sys


def load_unidecode():
    global unidecode
    try:
        unidecode  # check if loaded
    except NameError:
        import unidecode  # load, throw if can't


def quote_chars(text):
    # Use repr() to quote newlines, tabs, and other weird characters.
    # Do not use ascii(), because we want to allow non-ASCII in general (č, ñ).
    text = repr(str(text))
    # Remove outer quotes and inner \" \' \\ escapes added by repr()
    assert len(text) > 0
    assert text[0] in ("'", '"') and text[-1] == text[0]
    return re.sub(r'\\(\W)', r'\1', text[1:-1])


def text(iterable, *, ascii=False, raw=False):
    if ascii:
        load_unidecode()
        iterable = (unidecode.unidecode(s) for s in iterable)
    if not raw:
        iterable = (quote_chars(s) for s in iterable)
    return iterable


def uniq(iterable):
    seen = set()
    for element in iterable:
        if element not in seen:
            seen.add(element)
            yield element


def get_description(fid):
    try:
        return eyed3.id3.frames.ID3_FRAMES[fid][0]
    except KeyError:
        pass
    try:
        return eyed3.id3.frames.NONSTANDARD_ID3_FRAMES[fid][0]
    except (KeyError, AttributeError):
        pass
    try:
        alt = eyed3.id3.frames.TAGS2_2_TO_TAGS_2_3_AND_4[fid]
        if alt != fid:
            return get_description(alt)
    except (KeyError, AttributeError):
        pass
    return '?'


latin1_encoding_name = 'latin1'
utf_16_encoding_name = 'UTF-16'
utf_16be_encoding_name = 'UTF-16-big-endian'
utf_8_encoding_name = 'UTF-8'


def encoding_name(encoding):
    if encoding == eyed3.id3.LATIN1_ENCODING:
        return latin1_encoding_name
    elif encoding == eyed3.id3.UTF_16_ENCODING:
        return utf_16_encoding_name
    elif encoding == eyed3.id3.UTF_16BE_ENCODING:
        return utf_16be_encoding_name
    elif encoding == eyed3.id3.UTF_8_ENCODING:
        return utf_8_encoding_name
    else:
        return "encoding " + " ".join(("x%02X" % b) for b in encoding)


def encoding_code(name):
    if name == latin1_encoding_name:
        return eyed3.id3.LATIN1_ENCODING
    elif name == utf_16_encoding_name:
        return eyed3.id3.UTF_16_ENCODING
    elif name == utf_16be_encoding_name:
        return eyed3.id3.UTF_16BE_ENCODING
    elif name == utf_8_encoding_name:
        return eyed3.id3.UTF_8_ENCODING
    else:
        raise ValueError(f"Unknown encoding name '{name}'")


def get_frame_summary_key_value(info):
    if 'text' in info:
        return (info.get('description', None), info['text'], True)
    if 'url' in info:
        return (info.get('description', None), info['url'], True)
    if 'owner_id' in info and 'uniq_id' in info:
        return (info['owner_id'], info['uniq_id'], True)
    if 'owner_id' in info and 'owner_data' in info:
        if ((info['owner_id'] == 'PeakValue'
             or info['owner_id'] == 'AverageLevel')
                and len(info['owner_data']) == 4):
            return (info['owner_id'],
                    ("%d" % struct.unpack('<i', info['owner_data'])), True)
        else:
            return (info['owner_id'],
                    ("(%d byte(s))" % len(info['owner_data'])), False)
    if 'image_data' in info:
        return (None, ("(%d image byte(s))" % len(info['image_data'])), False)
    if 'data' in info:
        return (None, ("(%d raw byte(s))" % len(info['data'])), False)
    return (None, "(exists)", False)


def get_frame_summary(frame, *, ascii=False, raw=False):
    summary = {'id': frame.id.decode('ASCII'),
               'id_description': get_description(frame.id),
               'frame': frame}
    try:
        summary['text'] = frame.text
    except AttributeError:
        pass
    try:
        summary['description'] = frame.description
    except AttributeError:
        pass
    try:
        summary['url'] = frame.url
    except AttributeError:
        pass
    try:
        summary['user_url'] = frame.user_url
    except AttributeError:
        pass
    try:
        summary['owner_id'] = frame.owner_id
    except AttributeError:
        pass
    try:
        summary['uniq_id'] = frame.uniq_id
    except AttributeError:
        pass
    try:
        summary['owner_data'] = frame.owner_data
    except AttributeError:
        pass
    try:
        summary['image_data'] = frame.image_data
    except AttributeError:
        pass
    try:
        summary['data'] = frame.data
    except AttributeError:
        pass

    raw_encoding = None
    try:
        raw_encoding = frame.encoding
    except AttributeError:
        pass
    if raw_encoding is not None:
        summary['raw_encoding'] = raw_encoding
        summary['encoding'] = encoding_name(raw_encoding)
    try:
        summary['language'] = frame.lang.decode('ASCII')
    except AttributeError:
        pass
    try:
        summary['date'] = frame.date  # a date representation of frame.text
    except AttributeError:
        pass
    try:
        summary['mime_type'] = frame.mime_type
    except AttributeError:
        pass
    try:
        summary['picture_type'] = frame.picture_type
    except AttributeError:
        pass
    try:
        summary['filename'] = frame.filename
    except AttributeError:
        pass
    try:
        summary['toc'] = frame.toc
    except AttributeError:
        pass
    try:
        summary['rating'] = frame.rating
    except AttributeError:
        pass
    try:
        summary['email'] = frame.email
    except AttributeError:
        pass
    try:
        summary['count'] = frame.count
    except AttributeError:
        pass
    try:
        summary['title'] = frame.title
    except AttributeError:
        pass
    try:
        summary['subtitle'] = frame.subtitle
    except AttributeError:
        pass

    key, value, is_real_value = get_frame_summary_key_value(summary)
    if key is not None:
        key, = text((key,), ascii=ascii, raw=raw)
    value, = text((value,), ascii=ascii, raw=raw)

    if key is not None:
        summary['key'] = key
    if is_real_value:
        summary['value'] = value
    if key is None:
        summary['pretty'] = value
    else:
        summary['pretty'] = ('[%s] %s' % (key, value))

    return summary


def frame_props(tag, *, ascii=False, raw=False):
    return tuple(get_frame_summary(frame, ascii=ascii, raw=raw)
                 for frame in tag.frame_set.getAllFrames())


def abstract_props(tag, *, ascii=False, raw=False):
    props = (
        {'id': 'title', 'id_description': 'Track title',
         'value': tag.title},
        {'id': 'artist', 'id_description': 'Track artist',
         'value': tag.artist},
        {'id': 'album_artist', 'id_description': 'Album artist',
         'value': tag.album_artist},
        {'id': 'album', 'id_description': 'Album title',
         'value': tag.album},
        {'id': 'track_num', 'id_description': 'Track number',
         'value': tag.track_num[0]},
        {'id': 'num_tracks', 'id_description': 'Number of tracks in album',
         'value': tag.track_num[1]},
    )
    props = tuple(p for p in props if p['value'] is not None)
    for p in props:
        p['value'], = text((p['value'],), ascii=ascii, raw=raw)
        p['pretty'] = p['value']
    return props


def abstract_props_map(tag, *, ascii=False, raw=False):
    return {f['id']: f for f in abstract_props(tag, ascii=ascii, raw=raw)}


def all_props(tag, *, ascii=False, raw=False):
    return (*frame_props(tag, ascii=ascii, raw=raw),
            *abstract_props(tag, ascii=ascii, raw=raw))


def key_info(props):
    return tuple({'id': x[0], 'id_description': x[1]}
                 for x in uniq((y['id'], y['id_description']) for y in props))


def wipe_file(file):
    eyed3.id3.Tag.remove(file, version=eyed3.id3.ID3_ANY_VERSION)


def copy_id3(src_path, dst_path):
    file_src = eyed3.load(src_path)
    assert file_src, f"Could not load source {src_path!r}"
    if not file_src.tag:
        wipe_file(dst_path)
        return
    file_dst = eyed3.load(dst_path)
    assert file_dst, f"Could not load destination {dst_path!r}"
    file_dst.tag.frame_set = file_src.tag.frame_set
    # Use the old version, instead of hardcoding eyed3.id3.ID3_V2_3
    file_dst.tag.save(version=file_src.tag.version)


def remove_frame_from_frameset(frame_set, frame):
    frame_list = frame_set[frame.id]
    frame_list.remove(frame)  # error if missing
    if len(frame_list) == 0:
        del frame_set[frame.id]  # error if missing


def remove_frames_from_file(file, condition, *, restore_file_time=False):
    orig_stat = os.stat(file)
    id3file = eyed3.load(file)
    if not id3file:
        print(f"Could not load {file}!", file=sys.stderr)
        return
    if not id3file.tag:
        return
    assert id3file.tag
    frames = tuple(id3file.tag.frame_set.getAllFrames())
    for f in frames:
        if condition(f):
            remove_frame_from_frameset(id3file.tag.frame_set, f)
    id3file.tag.save()
    if restore_file_time:
        os.utime(file, ns=(orig_stat.st_atime_ns, orig_stat.st_mtime_ns))


def make_backup(file, *, revert=True, quiet=False):
    backup = file + '.bak'
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
                    print(f"While reverting '{backup}' -> '{file}': {e!r}",
                          file=sys.stderr)
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
