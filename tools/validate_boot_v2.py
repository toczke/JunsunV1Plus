#!/usr/bin/env python3
"""
validate_boot_v2.py - Android Boot Image Header v2 and DT Table Validator

Validates structural boundaries, alignment, declared offsets, and Google Android DT table
structures (DTBO and DTB) with multi-entry bounds checks and FDT header verification.
Designed for MediaTek MT8667 / MT6768 (Topway TS8667 / Junsun V1 Plus).
"""

import sys
import struct
import os

def validate_v2_image(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Image not found: {path}")

    file_sz = os.path.getsize(path)
    with open(path, "rb") as f:
        hdr = f.read(2048)
        if len(hdr) < 44:
            raise ValueError(f"Header too short: {len(hdr)} bytes")

        magic, k_sz, k_addr, r_sz, r_addr, s_sz, s_addr, tags_addr, page_sz, ver = struct.unpack("<8s9I", hdr[:44])
        if magic != b"ANDROID!":
            raise ValueError(f"Invalid magic: {magic} (expected b'ANDROID!')")
        if ver != 2:
            raise ValueError(f"Invalid header version: {ver} (expected 2)")
        if page_sz not in (2048, 4096):
            raise ValueError(f"Unexpected page size: {page_sz}")

        dtbo_sz, dtbo_off = struct.unpack("<IQ", hdr[1632:1644])
        hdr_sz, dtb_sz, dtb_addr = struct.unpack("<IIQ", hdr[1644:1660])

        if hdr_sz < 1660:
            raise ValueError(f"Invalid header size: {hdr_sz} < 1660")
        if k_sz == 0:
            raise ValueError("Kernel size is 0")
        if r_sz == 0:
            raise ValueError("Ramdisk size is 0")
        if dtbo_sz == 0:
            raise ValueError("Recovery DTBO size is 0 (required for display/touch panel)")
        if dtb_sz == 0:
            raise ValueError("DTB size is 0 (required for platform boot)")

        def pad(sz):
            return ((sz + page_sz - 1) // page_sz) * page_sz

        off_k = page_sz
        off_r = off_k + pad(k_sz)
        off_s = off_r + pad(r_sz)
        expected_dtbo_off = off_s + pad(s_sz)

        if dtbo_off != expected_dtbo_off:
            raise ValueError(f"Declared DTBO offset mismatch: {dtbo_off} != {expected_dtbo_off}")

        # Validate Recovery DTBO table structure and all entries
        f.seek(dtbo_off)
        dtbo_hdr = f.read(32)
        if len(dtbo_hdr) != 32:
            raise ValueError("Truncated DTBO table header")
        dtbo_magic, dtbo_total_sz, dtbo_hdr_sz, dtbo_entry_sz, dtbo_count, dtbo_entries_off, dtbo_page_sz, dtbo_ver = struct.unpack(">8I", dtbo_hdr)

        if dtbo_magic != 0xd7b7ab1e:
            raise ValueError(f"Invalid DTBO table magic: 0x{dtbo_magic:08x} (expected 0xd7b7ab1e)")
        if dtbo_total_sz != dtbo_sz or dtbo_total_sz < 32:
            raise ValueError(f"DTBO total_size mismatch: table {dtbo_total_sz} != boot header {dtbo_sz}")
        if dtbo_hdr_sz != 32 or dtbo_entry_sz < 32 or dtbo_entries_off < 32 or dtbo_count < 1:
            raise ValueError(f"Invalid DTBO table parameters: hdr_sz={dtbo_hdr_sz}, entry_sz={dtbo_entry_sz}, count={dtbo_count}")

        dtbo_entries_end = dtbo_entries_off + (dtbo_count * dtbo_entry_sz)
        if dtbo_entries_end > dtbo_total_sz:
            raise ValueError(f"DTBO entries exceed table total_size: {dtbo_entries_end} > {dtbo_total_sz}")

        for i in range(dtbo_count):
            f.seek(dtbo_off + dtbo_entries_off + (i * dtbo_entry_sz))
            entry_bytes = f.read(dtbo_entry_sz)
            if len(entry_bytes) < 32:
                raise ValueError(f"Truncated DTBO entry {i}")
            e_sz, e_off = struct.unpack(">II", entry_bytes[:8])
            if e_off < dtbo_entries_end or (e_off + e_sz) > dtbo_total_sz:
                raise ValueError(f"DTBO entry {i} bounds violation: [{e_off}, {e_off + e_sz}] in total {dtbo_total_sz}")
            f.seek(dtbo_off + e_off)
            fdt_hdr = f.read(8)
            if len(fdt_hdr) != 8:
                raise ValueError(f"Truncated FDT header in DTBO entry {i}")
            fdt_magic, fdt_totalsize = struct.unpack(">II", fdt_hdr)
            if fdt_magic != 0xd00dfeed:
                raise ValueError(f"Invalid FDT magic in DTBO entry {i}: 0x{fdt_magic:08x}")
            if fdt_totalsize != e_sz:
                raise ValueError(f"DTBO entry {i} FDT totalsize {fdt_totalsize} != entry dt_size {e_sz}")

        # Validate DTB table structure and all entries
        off_dtb = dtbo_off + pad(dtbo_sz)
        f.seek(off_dtb)
        dtb_hdr = f.read(32)
        if len(dtb_hdr) != 32:
            raise ValueError("Truncated DTB table header")
        dtb_magic, dtb_total_sz, dtb_hdr_sz, entry_sz, entry_count, entries_off, dtb_page_sz, dtb_ver = struct.unpack(">8I", dtb_hdr)

        if dtb_magic != 0xd7b7ab1e:
            raise ValueError(f"Invalid DTB magic: 0x{dtb_magic:08x} (expected 0xd7b7ab1e)")
        if dtb_total_sz != dtb_sz or dtb_total_sz < 32:
            raise ValueError(f"Invalid DTB table size: {dtb_total_sz} != {dtb_sz} or < 32")
        if dtb_hdr_sz != 32:
            raise ValueError(f"Invalid DTB header size: {dtb_hdr_sz} != 32")
        if entry_sz < 32:
            raise ValueError(f"Invalid DTB entry size: {entry_sz} < 32")
        if entries_off < dtb_hdr_sz:
            raise ValueError(f"Invalid DTB entries offset: {entries_off} < {dtb_hdr_sz}")
        if entry_count < 1:
            raise ValueError(f"DTB entry count < 1: {entry_count}")

        entries_end = entries_off + (entry_count * entry_sz)
        if entries_end > dtb_total_sz:
            raise ValueError(f"DTB entries boundary {entries_end} exceeds table size {dtb_total_sz}")

        for i in range(entry_count):
            f.seek(off_dtb + entries_off + (i * entry_sz))
            entry_data = f.read(entry_sz)
            if len(entry_data) < 32:
                raise ValueError(f"Truncated entry {i} read in DTB table")
            e_sz, e_off = struct.unpack(">II", entry_data[:8])

            if e_off < entries_end:
                raise ValueError(f"DTB Entry {i} offset {e_off} overlaps entries table (end={entries_end})")
            if (e_off + e_sz) > dtb_total_sz:
                raise ValueError(f"DTB Entry {i} FDT payload {e_off + e_sz} exceeds DTB table size {dtb_total_sz}")

            f.seek(off_dtb + e_off)
            fdt_hdr = f.read(8)
            if len(fdt_hdr) != 8:
                raise ValueError(f"Truncated FDT header read for DTB entry {i}")
            fdt_magic, fdt_totalsize = struct.unpack(">II", fdt_hdr)
            if fdt_magic != 0xd00dfeed:
                raise ValueError(f"Invalid FDT magic at DTB entry {i} offset +{e_off}: 0x{fdt_magic:08x}")
            if fdt_totalsize != e_sz:
                raise ValueError(f"DTB Entry {i} FDT totalsize {fdt_totalsize} != dt_size {e_sz}")

        total_payload = off_dtb + pad(dtb_sz)
        if file_sz < total_payload:
            raise ValueError(f"Image file size {file_sz} < calculated payload {total_payload}")

        return {
            "file": path,
            "version": ver,
            "page_size": page_sz,
            "kernel_size": k_sz,
            "ramdisk_size": r_sz,
            "dtbo_offset": dtbo_off,
            "dtbo_size": dtbo_sz,
            "dtbo_entries": dtbo_count,
            "dtb_offset": off_dtb,
            "dtb_size": dtb_sz,
            "dtb_entries": entry_count,
            "total_payload": total_payload,
            "file_size": file_sz
        }

if __name__ == "__main__":
    targets = sys.argv[1:] if len(sys.argv) > 1 else [
        "output_images/recovery_stock.img",
        "output_images/twrp_fixed_32mb.img"
    ]
    for target in targets:
        try:
            res = validate_v2_image(target)
            print(f"PASS: {target}")
            for k, v in res.items():
                print(f"  {k}: {v}")
        except Exception as err:
            print(f"FAIL: {target}: {err}", file=sys.stderr)
            sys.exit(1)
