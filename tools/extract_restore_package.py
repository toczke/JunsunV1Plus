#!/usr/bin/env python3
"""
extract_restore_package.py
Extracts all factory partition images from 8667.bin and diag_pack.tar.gz
for MediaTek MT6768 / spm8667p1_64 SP Flash Tool restoration.
"""

import os
import sys
import struct
import tarfile
import hashlib

BIN_PATH = "/run/media/tomasztoczek/TS8667_ROOT/8667.bin"
DIAG_TAR_PATH = "/run/media/tomasztoczek/TS8667_ROOT/diag_pack.tar.gz"
TARGET_DIR = "/run/media/tomasztoczek/TS8667_ROOT/SP_FLASH_TOOL_RESTORE_TS8667"

if not os.path.isfile(BIN_PATH):
    print(f"ERROR: Cannot find {BIN_PATH}")
    sys.exit(1)

if not os.path.isfile(DIAG_TAR_PATH):
    print(f"ERROR: Cannot find {DIAG_TAR_PATH}")
    sys.exit(1)

os.makedirs(TARGET_DIR, exist_ok=True)

# 1. Extracted parts from 8667.bin
BIN_PARTS = [
    ("super.img",    0x00000908, 3823937528),
    ("recovery.img", 0xe3ecb100, 33554432),
    ("spmfw.img",    0xe5ecb100, 49296),
    ("scp.img",      0xe5ed7190, 547040),
    ("sspm.img",     0xe5fe2350, 504208),
    ("lk.img",       0xe60d8670, 1510160),
    ("boot.img",     0xe63b9c90, 33554432),
    ("dtbo.img",     0xe83b9c90, 8388608),
    ("tee.img",      0xe8bb9c90, 128112),
]

print("==================================================")
print("EXTRACTING FACTORY PARTITION IMAGES FOR RESTORE")
print(f"Source 1: {BIN_PATH}")
print(f"Source 2: {DIAG_TAR_PATH}")
print(f"Target:   {TARGET_DIR}")
print("==================================================")

hasher_map = {}

with open(BIN_PATH, "rb") as bf:
    for name, offset, size in BIN_PARTS:
        out_path = os.path.join(TARGET_DIR, name)
        print(f"[-] Slicing {name} (0x{offset:08x}, {size} bytes)...", end="", flush=True)
        
        bf.seek(offset)
        hasher = hashlib.sha256()
        bytes_left = size
        chunk_size = 16 * 1024 * 1024
        
        with open(out_path, "wb") as of:
            while bytes_left > 0:
                to_read = min(chunk_size, bytes_left)
                data = bf.read(to_read)
                if not data:
                    break
                of.write(data)
                hasher.update(data)
                bytes_left -= len(data)
        
        sha = hasher.hexdigest()
        hasher_map[name] = sha
        print(f" DONE (SHA-256: {sha[:16]}...)")

# 2. Extract live dumps from diag_pack.tar.gz
TAR_PARTS = [
    ("diag_pack/vbmeta_stock.img",  "vbmeta.img"),
    ("diag_pack/vbmeta_system.img", "vbmeta_system.img"),
    ("diag_pack/vbmeta_vendor.img", "vbmeta_vendor.img"),
    ("diag_pack/seccfg.img",        "seccfg.img"),
    ("diag_pack/sec1.img",          "sec1.img"),
    ("diag_pack/tszone.img",        "tszone.img"),
    ("diag_pack/forfanzone.img",    "forfanzone.img"),
    ("diag_pack/forfanpara.img",    "forfanpara.img"),
    ("diag/misc.img",               "misc.img"),
    ("diag/para.img",               "para.img"),
]

with tarfile.open(DIAG_TAR_PATH, "r:gz") as tar:
    for src_tar, dest_name in TAR_PARTS:
        print(f"[-] Extracting {dest_name} from {src_tar}...", end="", flush=True)
        out_path = os.path.join(TARGET_DIR, dest_name)
        f_in = tar.extractfile(src_tar)
        if not f_in:
            print(" FAILED (member not found in tar)")
            continue
        hasher = hashlib.sha256()
        with open(out_path, "wb") as of:
            while chunk := f_in.read(1024 * 1024):
                of.write(chunk)
                hasher.update(chunk)
        sha = hasher.hexdigest()
        hasher_map[dest_name] = sha
        print(f" DONE (SHA-256: {sha[:16]}...)")

# Write sha256 checksums file
manifest_path = os.path.join(TARGET_DIR, "checksums.sha256")
with open(manifest_path, "w") as mf:
    for fn in sorted(hasher_map.keys()):
        mf.write(f"{hasher_map[fn]}  {fn}\n")

print("==================================================")
print(f"Manifest written to {manifest_path}")
print("==================================================")
