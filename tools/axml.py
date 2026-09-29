#!/usr/bin/env python3
"""Minimal binary AndroidManifest.xml (AXML) reader/writer.

Why this exists: only a 32-bit `aapt` is obtainable in this sandbox and it cannot run,
so the manifest is edited in-place at the binary level instead of being recompiled.
That also means resources.arsc and every resource file stay byte-identical to stock.

Correctness bar: parse(serialize(x)) == x byte-for-byte on the stock manifest.
`selftest` enforces that before any edit is trusted.
"""
import struct
import sys

RES_STRING_POOL = 0x0001
RES_XML = 0x0003
RES_XML_START_NAMESPACE = 0x0100
RES_XML_END_NAMESPACE = 0x0101
RES_XML_START_ELEMENT = 0x0102
RES_XML_END_ELEMENT = 0x0103
RES_XML_CDATA = 0x0104
RES_XML_RESOURCE_MAP = 0x0180

UTF8_FLAG = 1 << 8


class StringPool:
    def __init__(self, data=None):
        self.strings = []
        self.flags = 0
        self.sorted = False
        if data is not None:
            self._parse(data)

    def _parse(self, d):
        (_t, hs, _sz, n_str, n_sty, flags, str_start, sty_start) = struct.unpack_from('<HHIIIIII', d, 0)
        self.flags = flags
        utf8 = bool(flags & UTF8_FLAG)
        offs = struct.unpack_from('<%dI' % n_str, d, hs)
        for o in offs:
            p = str_start + o
            if utf8:
                # two lengths (chars, bytes), each 1-or-2 byte varint
                n, p = self._u8len(d, p)
                b, p = self._u8len(d, p)
                self.strings.append(d[p:p + b].decode('utf-8', 'replace'))
            else:
                ln = struct.unpack_from('<H', d, p)[0]
                p += 2
                if ln & 0x8000:
                    ln = ((ln & 0x7FFF) << 16) | struct.unpack_from('<H', d, p)[0]
                    p += 2
                self.strings.append(d[p:p + ln * 2].decode('utf-16-le', 'replace'))
        assert n_sty == 0, 'styled string pools are not supported (manifests never have them)'

    @staticmethod
    def _u8len(d, p):
        v = d[p]
        p += 1
        if v & 0x80:
            v = ((v & 0x7F) << 8) | d[p]
            p += 1
        return v, p

    def index(self, s):
        """Index of `s`, appending it to the end of the pool if absent.

        Appending at the end is required for safety: the resource-map chunk is
        positional and only covers the *prefix* of the pool, so existing indices
        (and their attribute resource IDs) must never shift.
        """
        try:
            return self.strings.index(s)
        except ValueError:
            self.strings.append(s)
            return len(self.strings) - 1

    def serialize(self):
        utf8 = bool(self.flags & UTF8_FLAG)
        blob = b''
        offs = []
        cache = {}
        for s in self.strings:
            if s in cache:
                offs.append(cache[s])
                continue
            cache[s] = len(blob)
            offs.append(len(blob))
            if utf8:
                enc = s.encode('utf-8')
                blob += self._p8len(len(s)) + self._p8len(len(enc)) + enc + b'\0'
            else:
                enc = s.encode('utf-16-le')
                blob += struct.pack('<H', len(s)) + enc + b'\0\0'
        while len(blob) % 4:
            blob += b'\0'
        hs = 28
        str_start = hs + 4 * len(offs)
        size = str_start + len(blob)
        head = struct.pack('<HHIIIIII', RES_STRING_POOL, hs, size,
                           len(offs), 0, self.flags, str_start, 0)
        return head + struct.pack('<%dI' % len(offs), *offs) + blob

    @staticmethod
    def _p8len(n):
        return bytes([n]) if n < 0x80 else bytes([0x80 | (n >> 8), n & 0xFF])


class Attr:
    __slots__ = ('ns', 'name', 'raw', 'size', 'res0', 'type', 'data')

    def __init__(self, ns, name, raw, size, res0, typ, data):
        self.ns, self.name, self.raw = ns, name, raw
        self.size, self.res0, self.type, self.data = size, res0, typ, data

    def copy(self):
        return Attr(self.ns, self.name, self.raw, self.size, self.res0, self.type, self.data)


class Node:
    """A START/END element pair, or a leaf chunk (namespace/cdata)."""

    def __init__(self, kind):
        self.kind = kind
        self.line = 0
        self.comment = 0xFFFFFFFF
        self.ns = 0xFFFFFFFF
        self.name = 0xFFFFFFFF
        self.attrs = []
        self.id_idx = 0
        self.class_idx = 0
        self.style_idx = 0
        self.children = []
        self.end_line = 0
        self.raw = None


class AXML:
    def __init__(self, data):
        self.data = data
        self.resmap = b''
        typ, hs, size = struct.unpack_from('<HHI', data, 0)
        assert typ == RES_XML, 'not a binary XML file'
        off = hs
        self.pool = None
        self.root = Node('root')
        stack = [self.root]
        while off < size:
            t, chs, csz = struct.unpack_from('<HHI', data, off)
            body = data[off:off + csz]
            if t == RES_STRING_POOL:
                self.pool = StringPool(body)
            elif t == RES_XML_RESOURCE_MAP:
                self.resmap = body
            elif t == RES_XML_START_ELEMENT:
                n = Node('el')
                n.line, n.comment, n.ns, n.name = struct.unpack_from('<IIII', body, 8)
                a_start, a_size, a_count, n.id_idx, n.class_idx, n.style_idx = \
                    struct.unpack_from('<HHHHHH', body, 24)
                for i in range(a_count):
                    # attributeStart is relative to the start of the attrExt
                    # struct, which begins at offset 16 (after the node header).
                    p = 16 + a_start + i * a_size
                    ns, nm, raw, sz, r0, ty, dt = struct.unpack_from('<IIIHBBI', body, p)
                    n.attrs.append(Attr(ns, nm, raw, sz, r0, ty, dt))
                stack[-1].children.append(n)
                stack.append(n)
            elif t == RES_XML_END_ELEMENT:
                line, _c, _ns, _nm = struct.unpack_from('<IIII', body, 8)
                stack[-1].end_line = line
                stack.pop()
            else:
                n = Node('raw')
                n.raw = body
                stack[-1].children.append(n)
            off += csz

    # -- helpers -------------------------------------------------------
    def s(self, i):
        return self.pool.strings[i] if i != 0xFFFFFFFF and i < len(self.pool.strings) else None

    def find(self, tag, parent=None):
        out = []
        for c in (parent or self.root).children:
            if c.kind == 'el' and self.s(c.name) == tag:
                out.append(c)
            out.extend(self.find(tag, c))
        return out

    def attr(self, node, name):
        for a in node.attrs:
            if self.s(a.name) == name:
                return a
        return None

    # -- writing -------------------------------------------------------
    def _emit(self, node, out):
        if node.kind == 'raw':
            out.append(node.raw)
            return
        a_size = 20
        body = struct.pack('<IIII', node.line, node.comment, node.ns, node.name)
        body += struct.pack('<HHHHHH', 20, a_size, len(node.attrs),
                            node.id_idx, node.class_idx, node.style_idx)
        for a in node.attrs:
            body += struct.pack('<IIIHBBI', a.ns, a.name, a.raw, a.size, a.res0, a.type, a.data)
        # headerSize is 16 (8-byte chunk header + line + comment), but `body`
        # already carries line/comment, so the total is 8 + len(body).
        out.append(struct.pack('<HHI', RES_XML_START_ELEMENT, 16, 8 + len(body)) + body)
        for c in node.children:
            self._emit(c, out)
        end = struct.pack('<IIII', node.end_line, 0xFFFFFFFF, node.ns, node.name)
        out.append(struct.pack('<HHI', RES_XML_END_ELEMENT, 16, 8 + len(end)) + end)

    def serialize(self):
        parts = [self.pool.serialize()]
        if self.resmap:
            parts.append(self.resmap)
        for c in self.root.children:
            self._emit(c, parts)
        payload = b''.join(parts)
        return struct.pack('<HHI', RES_XML, 8, 8 + len(payload)) + payload


def selftest(path):
    orig = open(path, 'rb').read()
    a = AXML(orig)
    out = a.serialize()
    if out == orig:
        print('AXML round-trip: BYTE-IDENTICAL (%d bytes)' % len(out))
        return 0
    print('AXML round-trip MISMATCH: %d vs %d bytes' % (len(orig), len(out)))
    for i in range(min(len(orig), len(out))):
        if orig[i] != out[i]:
            print('first diff at 0x%x' % i)
            print(' orig', orig[max(0, i - 8):i + 16].hex())
            print(' new ', out[max(0, i - 8):i + 16].hex())
            break
    return 1


if __name__ == '__main__':
    sys.exit(selftest(sys.argv[1]))
