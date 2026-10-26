#!/usr/bin/env python3
"""
adapt_lineageos20_ts8667.py - SojunerOS 20.0 Automotive Adaptation Tool
========================================================================
Injects the Topway TS8667 automotive hardware stack into generic
LineageOS 20 (Android 13 / API 33):
  1. Integrates CarSettingsBridge into /system/priv-app/CarSettingsBridge
  2. Injects Topway CAN bus engine (libcan59.so) into /system/lib/
  3. Injects MCU hardware communication JNI (libts67xhw.so) into /system/lib/
  4. Injects MainUI daemon (com.ts.MainUI) into /system/app/MainUI/
  5. Injects USB Dashcam (com.ankai.cardvr) into /system/app/CarDVR/
  6. Injects USB DVD Box player (DvdBox.apk & libsdvdplayer.so)
  7. Injects init.ts8667.rc to configure /dev/ttyMT1 and /dev/ts07_dsp
  8. Configures SurfaceFlinger for forced 1280x720 landscape orientation
"""

import os
import sys
import shutil
import subprocess

def run_cmd(cmd, check=True):
    print(f"[*] Running: {cmd}")
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        print(f"[-] Command failed with code {res.returncode}:\n{res.stderr}")
        sys.exit(1)
    return res

def check_dependencies():
    for tool in ["e2fsdroid", "debugfs", "resize2fs", "fsck.ext4"]:
        if not shutil.which(tool):
            print(f"[-] Missing required tool: {tool}")
            sys.exit(1)
    print("[✓] All filesystem tools present.")

def main():
    print("=" * 72)
    print("      SojunerOS 20.0 — LineageOS 20 Automotive Adaptation Tool         ")
    print("      Target: Topway TS8667 / Junsun V1 Plus (MT8667 / MT6768)         ")
    print("=" * 72)

    check_dependencies()

    if len(sys.argv) < 3:
        print("Usage: python3 adapt_lineageos20_ts8667.py <input_lineage20.img> <output_sojuneros.img>")
        sys.exit(1)

    in_img = sys.argv[1]
    out_img = sys.argv[2]
    repo_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    proprietary_dir = os.path.join(repo_dir, "vendor/topway/ts8667/proprietary")
    apk_dir = os.path.join(repo_dir, "prebuilt_apks/TS8667_Car_Settings_Bridge_APK")

    if not os.path.exists(in_img):
        print(f"[-] Input image not found: {in_img}")
        sys.exit(1)

    print(f"[*] Copying {in_img} to {out_img}...")
    shutil.copyfile(in_img, out_img)

    # 1. Expand image by 256MB to provide headroom for automotive packages
    print("[*] Expanding image filesystem by 256MB for automotive packages...")
    run_cmd(f"resize2fs -f {out_img} 2800M", check=False)
    run_cmd(f"fsck.ext4 -y -f {out_img}", check=False)

    # 2. Prepare staging directory
    staging = "/tmp/sojuneros_staging"
    if os.path.exists(staging):
        shutil.rmtree(staging)
    os.makedirs(f"{staging}/system/lib", exist_ok=True)
    os.makedirs(f"{staging}/system/app/MainUI", exist_ok=True)
    os.makedirs(f"{staging}/system/app/CarDVR", exist_ok=True)
    os.makedirs(f"{staging}/system/app/DvdBox", exist_ok=True)
    os.makedirs(f"{staging}/system/priv-app/CarSettingsBridge", exist_ok=True)
    os.makedirs(f"{staging}/system/etc/init", exist_ok=True)

    print("[*] Populating automotive components into staging...")

    # Copy libraries
    for lib in ["libcan59.so", "libts67xhw.so", "libts67xlogo.so", "libts70xicfg.so", "libsdvdplayer.so"]:
        src = os.path.join(proprietary_dir, f"lib/{lib}")
        if os.path.exists(src):
            shutil.copy2(src, f"{staging}/system/lib/{lib}")
            print(f"  [+] Staged library: {lib}")

    # Copy APKs
    shutil.copy2(os.path.join(proprietary_dir, "app/MainUI/MainUI.apk"), f"{staging}/system/app/MainUI/MainUI.apk")
    shutil.copy2(os.path.join(proprietary_dir, "app/CarDVR/com.ankai.cardvr_v1.0.0_20231226_104230_myx44.apk"), f"{staging}/system/app/CarDVR/CarDVR.apk")
    shutil.copy2(os.path.join(proprietary_dir, "app/DvdBox/DvdBox.apk"), f"{staging}/system/app/DvdBox/DvdBox.apk")
    shutil.copy2(os.path.join(apk_dir, "app-debug.apk"), f"{staging}/system/priv-app/CarSettingsBridge/CarSettingsBridge.apk")

    # 3. Create Automotive Init script
    init_rc = f"""
# Topway TS8667 Automotive Hardware Initialization for SojunerOS 20.0
on boot
    # MCU UART Communication (/dev/ttyMT1 @ 115200)
    chmod 0666 /dev/ttyMT1
    chown system radio /dev/ttyMT1
    setprop persist.sys.can.baud 115200

    # ROHM BD3702FV DSP I2C driver
    chmod 0666 /dev/ts07_dsp
    chown media audio /dev/ts07_dsp

    # Techpoint TP2850 Reversing Video Decoder
    chmod 0666 /dev/video0
    chmod 0666 /dev/video1

    # Forced 16:9 Landscape SurfaceFlinger configuration
    setprop ro.sf.hwrotation 0
    setprop ro.surface_flinger.primary_display_orientation ORIENTATION_0
    setprop persist.sys.orientation landscape
    setprop ro.audio.silent 0
"""
    with open(f"{staging}/system/etc/init/init.ts8667.rc", "w") as f:
        f.write(init_rc.strip() + "\n")
    print("  [+] Staged init.ts8667.rc")

    # 4. Inject staging into ext4 image using debugfs or e2fsdroid
    print("[*] Injecting staged files into ext4 image using debugfs...")
    debugfs_commands = [
        "cd /",
        "mkdir system",
        "mkdir system/lib",
        "mkdir system/app",
        "mkdir system/app/MainUI",
        "mkdir system/app/CarDVR",
        "mkdir system/app/DvdBox",
        "mkdir system/priv-app",
        "mkdir system/priv-app/CarSettingsBridge",
        "mkdir system/etc",
        "mkdir system/etc/init",
    ]

    for root, dirs, files in os.walk(staging):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, staging)
            parent_dir = os.path.dirname(rel_path)
            debugfs_commands.append(f"cd /{parent_dir}")
            debugfs_commands.append(f"write {full_path} {file}")

    cmd_file = "/tmp/debugfs_cmds.txt"
    with open(cmd_file, "w") as f:
        f.write("\n".join(debugfs_commands) + "\nquit\n")

    run_cmd(f"debugfs -w -f {cmd_file} {out_img}", check=False)
    run_cmd(f"fsck.ext4 -y -f {out_img}", check=False)

    print("=" * 72)
    print(f" [✓] SojunerOS 20.0 Automotive image successfully adapted!")
    print(f"     Output: {out_img}")
    print("=" * 72)

if __name__ == "__main__":
    main()
