#!/usr/bin/env python3
import os, sys

def inspect_partition(img_path):
    print(f"[*] Checking {img_path}...")
    size = os.path.getsize(img_path)
    print(f"    Size: {size / (1024*1024):.2f} MB")

if __name__ == "__main__":
    p_dir = "/home/tomasztoczek/Downloads/fw_8667_extract/partitions"
    for img in ["system.img", "vendor.img", "product.img", "boot.img"]:
        path = os.path.join(p_dir, img)
        if os.path.exists(path):
            inspect_partition(path)
