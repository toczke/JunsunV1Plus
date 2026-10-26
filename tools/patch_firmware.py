#!/usr/bin/env python3
"""
patch_firmware.py - Slices a custom recovery or partition into 8667.bin
and generates the matching 8667.upd MD5 file.
"""

import sys, os, hashlib

RECOVERY_OFFSET = 3823939840  # 0xe3ecb100
RECOVERY_MAX_SIZE = 33554432  # 32 MB

def patch_recovery(bin_path, recovery_img_path, out_bin_path=None):
    if out_bin_path is None:
        out_bin_path = bin_path

    rec_size = os.path.getsize(recovery_img_path)
    if rec_size > RECOVERY_MAX_SIZE:
        print(f"Error: {recovery_img_path} ({rec_size} bytes) exceeds 32MB limit ({RECOVERY_MAX_SIZE} bytes)")
        return False

    with open(recovery_img_path, "rb") as rf:
        rec_data = rf.read()

    # Pad to 32MB if needed
    if len(rec_data) < RECOVERY_MAX_SIZE:
        rec_data += b"\x00" * (RECOVERY_MAX_SIZE - len(rec_data))

    print(f"Splicing {recovery_img_path} into {out_bin_path} at offset {RECOVERY_OFFSET:#x}...")
    with open(out_bin_path, "r+b") as bf:
        bf.seek(RECOVERY_OFFSET)
        bf.write(rec_data)

    print("Calculating new MD5 checksum for 8667.upd...")
    hasher = hashlib.md5()
    with open(out_bin_path, "rb") as bf:
        while chunk := bf.read(16 * 1024 * 1024):
            hasher.update(chunk)
    
    new_md5 = hasher.hexdigest()
    upd_path = os.path.splitext(out_bin_path)[0] + ".upd"
    with open(upd_path, "w") as uf:
        uf.write(new_md5 + "\n")

    print(f"Success! Generated {upd_path} with MD5: {new_md5}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 patch_firmware.py <8667.bin> <custom_recovery.img> [output_8667.bin]")
        sys.exit(1)
    
    bin_file = sys.argv[1]
    rec_file = sys.argv[2]
    out_file = sys.argv[3] if len(sys.argv) > 3 else bin_file
    patch_recovery(bin_file, rec_file, out_file)
