#!/usr/bin/env python3
"""Targeted ARM/Thumb disassembler for libminecraftpe.so (read-only analysis).

Resolves ELF vaddr->file offset, follows Thumb/ARM mode from the low symbol bit,
and annotates PC-relative literal loads with the string/pointer they reference --
which is what actually matters when chasing hardcoded paths and option keys.

Usage:
  ndis.py <lib.so> sym <regex>              list matching dynamic symbols
  ndis.py <lib.so> dis <symbol-or-0xaddr> [n_bytes]
  ndis.py <lib.so> xref <0xaddr>            find literal-pool refs to an address
"""
import re
import sys
import struct

from capstone import (CS_ARCH_ARM, CS_MODE_ARM, CS_MODE_THUMB, Cs)


class ELF:
    def __init__(self, path):
        self.data = open(path, 'rb').read()
        d = self.data
        assert d[:4] == b'\x7fELF', 'not an ELF'
        e_shoff, = struct.unpack_from('<I', d, 0x20)
        e_shentsize, e_shnum, e_shstrndx = struct.unpack_from('<HHH', d, 0x2E)
        self.sections = []
        for i in range(e_shnum):
            off = e_shoff + i * e_shentsize
            name, typ, flags, addr, offset, size, link, info, align, entsize = \
                struct.unpack_from('<IIIIIIIIII', d, off)
            self.sections.append(dict(name=name, type=typ, addr=addr, offset=offset,
                                      size=size, link=link, entsize=entsize))
        sh = self.sections[e_shstrndx]
        strtab = d[sh['offset']:sh['offset'] + sh['size']]
        for s in self.sections:
            end = strtab.find(b'\0', s['name'])
            s['sname'] = strtab[s['name']:end].decode()
        self.symbols = self._syms()

    def sec(self, name):
        for s in self.sections:
            if s['sname'] == name:
                return s
        return None

    def _syms(self):
        out = []
        for secname, strname in (('.dynsym', '.dynstr'), ('.symtab', '.strtab')):
            sy, st = self.sec(secname), self.sec(strname)
            if not sy or not st:
                continue
            strs = self.data[st['offset']:st['offset'] + st['size']]
            n = sy['size'] // 16
            for i in range(n):
                off = sy['offset'] + i * 16
                nm, val, size, info, other, shndx = struct.unpack_from('<IIIBBH', self.data, off)
                end = strs.find(b'\0', nm)
                name = strs[nm:end].decode('utf8', 'replace')
                if name:
                    out.append(dict(name=name, value=val, size=size, info=info))
        return out

    def v2o(self, vaddr):
        for s in self.sections:
            if s['addr'] and s['addr'] <= vaddr < s['addr'] + s['size'] and s['type'] != 8:
                return s['offset'] + (vaddr - s['addr'])
        return None

    def read(self, vaddr, n):
        o = self.v2o(vaddr)
        return self.data[o:o + n] if o is not None else None

    def cstr(self, vaddr, maxlen=200):
        o = self.v2o(vaddr)
        if o is None:
            return None
        end = self.data.find(b'\0', o, o + maxlen)
        if end < 0:
            return None
        try:
            s = self.data[o:end].decode('utf8')
        except UnicodeDecodeError:
            return None
        return s if all(32 <= ord(c) < 127 for c in s) else None


def disas(elf, vaddr, nbytes):
    thumb = vaddr & 1
    base = vaddr & ~1
    code = elf.read(base, nbytes)
    if code is None:
        print('!! address not mapped')
        return
    md = Cs(CS_ARCH_ARM, CS_MODE_THUMB if thumb else CS_MODE_ARM)
    md.detail = False
    print(f'; {"THUMB" if thumb else "ARM"} @ 0x{base:08x}  ({nbytes} bytes)')
    for ins in md.disasm(code, base):
        line = f'  0x{ins.address:08x}  {ins.mnemonic:<8} {ins.op_str}'
        m = re.search(r'\[pc, #(\d+)\]', ins.op_str)
        if m and ins.mnemonic.startswith('ldr'):
            pc = (ins.address + 4) & ~3
            lit = pc + int(m.group(1))
            raw = elf.read(lit, 4)
            if raw:
                val, = struct.unpack('<I', raw)
                line += f'    ; [0x{lit:08x}] = 0x{val:08x}'
                s = elf.cstr(val)
                if s:
                    line += f' -> {s!r}'
                else:
                    for sym in elf.symbols:
                        if sym['value'] in (val, val | 1) and sym['name']:
                            line += f' -> {sym["name"]}'
                            break
        print(line)


def main():
    elf = ELF(sys.argv[1])
    cmd = sys.argv[2]
    if cmd == 'sym':
        rx = re.compile(sys.argv[3])
        seen = set()
        for s in elf.symbols:
            if rx.search(s['name']) and s['name'] not in seen:
                seen.add(s['name'])
                print(f'0x{s["value"]:08x} {s["size"]:6d}  {s["name"]}')
    elif cmd == 'dis':
        t = sys.argv[3]
        if t.startswith('0x'):
            va, size = int(t, 16), None
        else:
            cand = [s for s in elf.symbols if s['name'] == t]
            if not cand:
                cand = [s for s in elf.symbols if t in s['name']]
            if not cand:
                sys.exit(f'symbol not found: {t}')
            va, size = cand[0]['value'], cand[0]['size']
        n = int(sys.argv[4]) if len(sys.argv) > 4 else (size or 64)
        disas(elf, va, max(n, 8))
    elif cmd == 'xref':
        target = int(sys.argv[3], 16)
        needle = struct.pack('<I', target)
        start = 0
        while True:
            i = elf.data.find(needle, start)
            if i < 0:
                break
            start = i + 1
            for s in elf.sections:
                if s['offset'] and s['offset'] <= i < s['offset'] + s['size'] and s['addr']:
                    print(f'  {s["sname"]} file=0x{i:x} vaddr=0x{s["addr"] + i - s["offset"]:08x}')
                    break


if __name__ == '__main__':
    main()
