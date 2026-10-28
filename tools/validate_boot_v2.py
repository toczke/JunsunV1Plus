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
import hashlib
import argparse

def validate_v2_image(path, truncate=False, max_partition_size=None):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Image not found: {path}")

    mode = "r+b" if truncate else "rb"
    with open(path, mode) as f:
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
            raise ValueError(f"Declared DTBO offset mismatch: declared {dtbo_off} != expected {expected_dtbo_off}")

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
        if dtbo_hdr_sz != 32:
            raise ValueError(f"Invalid DTBO header size: {dtbo_hdr_sz} != 32")
        if dtbo_entry_sz != 32:
            raise ValueError(f"Invalid standard DTBO entry size: {dtbo_entry_sz} != 32")
        if dtbo_ver != 0:
            raise ValueError(f"Invalid DTBO table version: {dtbo_ver} != 0")
        if dtbo_page_sz != page_sz:
            raise ValueError(f"DTBO table page_size mismatch: {dtbo_page_sz} != boot image {page_sz}")
        if dtbo_entries_off < 32:
            raise ValueError(f"Invalid DTBO entries offset: {dtbo_entries_off} < 32")
        if dtbo_count < 1:
            raise ValueError(f"DTBO entry count < 1: {dtbo_count}")

        dtbo_entries_end = dtbo_entries_off + (dtbo_count * dtbo_entry_sz)
        if dtbo_entries_end > dtbo_total_sz:
            raise ValueError(f"DTBO entries exceed table total_size: {dtbo_entries_end} > {dtbo_total_sz}")

        for i in range(dtbo_count):
            f.seek(dtbo_off + dtbo_entries_off + (i * dtbo_entry_sz))
            entry_bytes = f.read(dtbo_entry_sz)
            if len(entry_bytes) != 32:
                raise ValueError(f"Truncated DTBO entry {i} read: {len(entry_bytes)} != 32")
            e_sz, e_off = struct.unpack(">II", entry_bytes[:8])
            if e_off < dtbo_entries_end or (e_off + e_sz) > dtbo_total_sz:
                raise ValueError(f"DTBO entry {i} bounds violation: [{e_off}, {e_off + e_sz}] in total {dtbo_total_sz}")
            f.seek(dtbo_off + e_off)
            fdt_hdr = f.read(8)
            if len(fdt_hdr) != 8:
                raise ValueError(f"Truncated FDT header in DTBO entry {i}")
            fdt_magic, fdt_totalsize = struct.unpack(">II", fdt_hdr)
            if fdt_magic != 0xd00dfeed:
                raise ValueError(f"Invalid FDT magic in DTBO entry {i}: 0x{fdt_magic:08x} (expected 0xd00dfeed)")
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
        if entry_sz != 32:
            raise ValueError(f"Invalid standard DTB entry size: {entry_sz} != 32")
        if dtb_ver != 0:
            raise ValueError(f"Invalid DTB table version: {dtb_ver} != 0")
        if dtb_page_sz != page_sz:
            raise ValueError(f"DTB table page_size mismatch: {dtb_page_sz} != boot image {page_sz}")
        if entries_off < 32:
            raise ValueError(f"Invalid DTB entries offset: {entries_off} < 32")
        if entry_count < 1:
            raise ValueError(f"DTB entry count < 1: {entry_count}")

        entries_end = entries_off + (entry_count * entry_sz)
        if entries_end > dtb_total_sz:
            raise ValueError(f"DTB entries boundary {entries_end} exceeds table size {dtb_total_sz}")

        for i in range(entry_count):
            f.seek(off_dtb + entries_off + (i * entry_sz))
            entry_data = f.read(entry_sz)
            if len(entry_data) != 32:
                raise ValueError(f"Truncated entry {i} read in DTB table: {len(entry_data)} != 32")
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
        f.seek(0, 2)
        file_sz = f.tell()

        if file_sz < total_payload:
            raise ValueError(f"Image file size {file_sz} < calculated payload {total_payload} (truncated file)")

        if max_partition_size is not None:
            if (total_payload + 64) > max_partition_size:
                raise ValueError(f"Calculated payload ({total_payload} B) + AVB footer (64 B) exceeds partition size ({max_partition_size} B)")

        truncated_action = False
        if truncate and file_sz > total_payload:
            f.truncate(total_payload)
            file_sz = total_payload
            truncated_action = True

        f.seek(0)
        h = hashlib.sha256()
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
        digest = h.hexdigest()

        return {
            "file": path,
            "version": ver,
            "page_size": page_sz,
            "header_size": hdr_sz,
            "kernel_size": k_sz,
            "ramdisk_size": r_sz,
            "dtbo_offset": dtbo_off,
            "dtbo_size": dtbo_sz,
            "dtbo_entries": dtbo_count,
            "dtbo_table_version": dtbo_ver,
            "dtbo_table_page_size": dtbo_page_sz,
            "dtb_offset": off_dtb,
            "dtb_size": dtb_sz,
            "dtb_entries": entry_count,
            "dtb_table_version": dtb_ver,
            "dtb_table_page_size": dtb_page_sz,
            "total_payload": total_payload,
            "file_size": file_sz,
            "truncated": truncated_action,
            "sha256": digest
        }

def main():
    parser = argparse.ArgumentParser(description="Android Boot Image v2 & DT Table Validator")
    parser.add_argument("images", nargs="*", default=["output_images/recovery_stock.img", "output_images/twrp_fixed_32mb.img"],
                        help="Path(s) to recovery or boot image files to validate")
    parser.add_argument("--truncate", action="store_true",
                        help="Truncate image to total_payload size if larger (used before appending AVB footer)")
    parser.add_argument("--max-partition-size", type=int, default=None,
                        help="Verify total_payload + 64 bytes fits within maximum partition size (e.g. 33554432)")

    args = parser.parse_args()

    success = True
    for img in args.images:
        try:
            res = validate_v2_image(img, truncate=args.truncate, max_partition_size=args.max_partition_size)
            print(f"PASS: {img}")
            for k, v in res.items():
                print(f"  {k}: {v}")
        except Exception as err:
            print(f"FAIL: {img}: {err}", file=sys.stderr)
            success = False

    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
