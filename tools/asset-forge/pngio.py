"""Minimal PNG read/write on the standard library, so validators and pixel recipes need no Pillow.

read(path) -> (width, height, rows): rows[y] is a list of (r, g, b, a) tuples, 8-bit, for
non-interlaced 8- or 16-bit greyscale, grey+alpha, RGB, RGBA and palette images.
write(path, width, height, rows): rows of (r, g, b, a) 8-bit tuples, written as RGBA8.
"""

import struct
import zlib

SIG = b"\x89PNG\r\n\x1a\n"
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def _chunks(data):
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        yield kind, data[pos + 8:pos + 8 + length]
        pos += 12 + length


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _unfilter(raw, height, stride, bpp):
    out, prev, pos = [], bytearray(stride), 0
    for _ in range(height):
        ftype, line = raw[pos], bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if ftype == 1:
                line[i] = (line[i] + a) & 255
            elif ftype == 2:
                line[i] = (line[i] + b) & 255
            elif ftype == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif ftype == 4:
                line[i] = (line[i] + _paeth(a, b, c)) & 255
            elif ftype != 0:
                raise ValueError("bad PNG filter %d" % ftype)
        out.append(line)
        prev = line
    return out


def read(path):
    data = open(path, "rb").read()
    if data[:8] != SIG:
        raise ValueError("not a PNG: %s" % path)
    idat, palette, trns = bytearray(), None, None
    for kind, body in _chunks(data):
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
    if interlace or depth not in (8, 16) or ctype not in CHANNELS:
        raise ValueError("unsupported PNG (depth %d, type %d, interlace %d)" % (depth, ctype, interlace))
    nch, size = CHANNELS[ctype], depth // 8
    bpp = nch * size
    lines = _unfilter(zlib.decompress(bytes(idat)), height, width * bpp, bpp)
    rows = []
    for line in lines:
        if size == 2:
            vals = [((line[i] << 8 | line[i + 1]) + 128) // 257 for i in range(0, len(line), 2)]
        else:
            vals = line
        row = []
        for x in range(width):
            px = vals[x * nch:(x + 1) * nch]
            if ctype == 0:
                row.append((px[0], px[0], px[0], 255))
            elif ctype == 4:
                row.append((px[0], px[0], px[0], px[1]))
            elif ctype == 2:
                row.append((px[0], px[1], px[2], 255))
            elif ctype == 6:
                row.append(tuple(px))
            else:
                r, g, b = palette[px[0]]
                row.append((r, g, b, trns[px[0]] if trns and px[0] < len(trns) else 255))
        rows.append(row)
    return width, height, rows


def write(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    with open(path, "wb") as f:
        f.write(SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
