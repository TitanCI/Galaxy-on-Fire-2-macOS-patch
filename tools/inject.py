#!/usr/bin/env python3
"""Add an LC_LOAD_DYLIB command to a thin x86_64 Mach-O (unsigned) in place."""
import struct, sys

path, dylib = sys.argv[1], sys.argv[2]
data = bytearray(open(path, "rb").read())
magic, cputype, cpusub, ftype, ncmds, sizeofcmds, flags, res = struct.unpack_from("<IiiIIIII", data, 0)
assert magic == 0xFEEDFACF, "not a thin 64-bit Mach-O"

off, first_content = 32, 1 << 62
for _ in range(ncmds):
    cmd, size = struct.unpack_from("<II", data, off)
    if cmd == 0x19:  # LC_SEGMENT_64
        nsects = struct.unpack_from("<I", data, off + 64)[0]
        for i in range(nsects):
            s = off + 72 + i * 80
            sect_off = struct.unpack_from("<I", data, s + 48)[0]
            if sect_off:
                first_content = min(first_content, sect_off)
    off += size

name = dylib.encode() + b"\0"
cmdsize = (24 + len(name) + 7) & ~7
assert 32 + sizeofcmds + cmdsize <= first_content, "no header space"
lc = struct.pack("<IIIIII", 0xC, cmdsize, 24, 2, 0x10000, 0x10000) + name
lc += b"\0" * (cmdsize - len(lc))
data[32 + sizeofcmds:32 + sizeofcmds + cmdsize] = lc
struct.pack_into("<II", data, 16, ncmds + 1, sizeofcmds + cmdsize)
open(path, "wb").write(data)
print("injected", dylib)
