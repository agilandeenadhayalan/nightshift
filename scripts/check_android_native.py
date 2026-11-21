"""Check 64-bit APK ELF/ZIP alignment; this is not a 16 KB runtime test."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

PAGE = 16384
MAX_HEADERS = 4 * 1024 * 1024
MACHINES = {"arm64-v8a": 183, "x86_64": 62}


def elf_alignment(source, length: int, machine: int) -> bool:
    header = source.read(64)
    if len(header) != 64 or header[:7] != b"\x7fELF\x02\x01\x01":
        raise ValueError("expected a complete little-endian ELF64 header")
    if struct.unpack_from("<H", header, 18)[0] != machine:
        raise ValueError("ELF architecture does not match its APK ABI")
    offset = struct.unpack_from("<Q", header, 32)[0]
    header_size, entry_size, count = struct.unpack_from("<HHH", header, 52)
    end = offset + entry_size * count
    if (header_size != 64 or entry_size != 56 or not 0 < count <= 4096
            or offset < 64 or end > min(length, MAX_HEADERS)):
        raise ValueError("invalid or unbounded ELF program-header table")
    source.read(offset - 64)
    entries = source.read(entry_size * count)
    if len(entries) != entry_size * count:
        raise ValueError("truncated ELF program-header table")
    loads = 0
    aligned = True
    for index in range(count):
        kind, _, file_offset, address, _, size, memory_size, alignment = struct.unpack_from(
            "<IIQQQQQQ", entries, index * entry_size)
        if kind != 1:
            continue
        loads += 1
        if size > memory_size or file_offset + size > length:
            raise ValueError("invalid ELF load segment bounds")
        aligned = aligned and (
            alignment >= PAGE and alignment & (alignment - 1) == 0
            and file_offset % alignment == address % alignment
            and file_offset % PAGE == address % PAGE)
    if not loads:
        raise ValueError("ELF has no load segments")
    return aligned


def inspect_apk(apk: Path) -> dict:
    libraries = []
    seen = set()
    with apk.open("rb") as raw, zipfile.ZipFile(apk) as archive:
        for item in archive.infolist():
            parts = item.filename.split("/")
            if (len(parts) != 3 or parts[0] != "lib"
                    or parts[1] not in MACHINES or not parts[2].endswith(".so")):
                continue
            if item.filename in seen:
                raise ValueError("duplicate native library entry")
            seen.add(item.filename)
            if item.flag_bits & 1:
                raise ValueError("encrypted native library entry")
            with archive.open(item) as source:
                elf_ok = elf_alignment(source, item.file_size, MACHINES[parts[1]])
            raw.seek(item.header_offset)
            local = raw.read(30)
            if len(local) != 30 or local[:4] != b"PK\x03\x04":
                raise ValueError("invalid ZIP local header")
            name_length, extra_length = struct.unpack_from("<HH", local, 26)
            data_offset = item.header_offset + 30 + name_length + extra_length
            stored = item.compress_type == zipfile.ZIP_STORED
            libraries.append({
                "library": item.filename,
                "elf16kbAligned": elf_ok,
                "stored": stored,
                "zip16kbAligned": data_offset % PAGE == 0 if stored else None,
            })
    if not libraries:
        raise ValueError("APK contains no supported 64-bit native libraries")
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "artifact": apk.name,
        "sha256": digest,
        "libraries": libraries,
        "allElfAligned": all(row["elf16kbAligned"] for row in libraries),
        "allStoredZipAligned": all(row["zip16kbAligned"] is not False for row in libraries),
        "runtime16kbTested": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--report", type=Path, help="optional JSON report destination")
    args = parser.parse_args()
    try:
        result = inspect_apk(args.apk)
    except (OSError, ValueError, struct.error, zipfile.BadZipFile, RuntimeError) as error:
        print(f"Native artifact check failed: {error}", file=sys.stderr)
        return 2
    if args.report:
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    failed = [row["library"] for row in result["libraries"]
              if not row["elf16kbAligned"] or row["zip16kbAligned"] is False]
    print(json.dumps({key: value for key, value in result.items() if key != "libraries"}
                     | {"libraryCount": len(result["libraries"]), "incompatible": failed}))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
