#!/usr/bin/env python3
"""
generate_scatter.py
Generates the standard MediaTek MT6768 scatter file (MT6768_Android_scatter.txt)
for Topway TS8667 / Junsun V1 Plus (spm8667p1_64).
Addresses and partition sizes match the physical device eMMC GPT structure.
"""

import os
import sys

def generate_scatter_content():
    content = """############################################################################################################
#
#  General Setting
#
############################################################################################################
- general: MTK_PLATFORM_CFG
  info: 
    - config_version: V1.1.2
      platform: MT6768
      project: spm8667p1_64
      storage: EMMC
      boot_channel: MSDC_0
      block_size: 0x20000
############################################################################################################
#
#  Layout Setting
#
############################################################################################################
- partition_index: SYS0
  partition_name: preloader
  file_name: NONE
  is_download: false
  type: SV5_BL_BIN
  linear_start_addr: 0x0
  physical_start_addr: 0x0
  partition_size: 0x400000
  region: EMMC_BOOT_1
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: BOOTLOADERS
  reserve: 0x00

- partition_index: SYS1
  partition_name: pgpt
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x0
  physical_start_addr: 0x0
  partition_size: 0x8000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS2
  partition_name: recovery
  file_name: recovery.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x8000
  physical_start_addr: 0x8000
  partition_size: 0x2000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS3
  partition_name: misc
  file_name: misc.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2008000
  physical_start_addr: 0x2008000
  partition_size: 0x80000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS4
  partition_name: para
  file_name: para.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2088000
  physical_start_addr: 0x2088000
  partition_size: 0x80000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS5
  partition_name: forfanzone
  file_name: forfanzone.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2108000
  physical_start_addr: 0x2108000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS6
  partition_name: tszone
  file_name: tszone.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2208000
  physical_start_addr: 0x2208000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS7
  partition_name: forfanpara
  file_name: forfanpara.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2308000
  physical_start_addr: 0x2308000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS8
  partition_name: avm
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x2408000
  physical_start_addr: 0x2408000
  partition_size: 0x6400000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS9
  partition_name: expdb
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x8808000
  physical_start_addr: 0x8808000
  partition_size: 0x1400000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS10
  partition_name: frp
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x9c08000
  physical_start_addr: 0x9c08000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS11
  partition_name: vbmeta
  file_name: vbmeta.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x9d08000
  physical_start_addr: 0x9d08000
  partition_size: 0x800000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS12
  partition_name: vbmeta_system
  file_name: vbmeta_system.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0xa508000
  physical_start_addr: 0xa508000
  partition_size: 0x800000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS13
  partition_name: vbmeta_vendor
  file_name: vbmeta_vendor.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0xad08000
  physical_start_addr: 0xad08000
  partition_size: 0x800000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS14
  partition_name: md_udc
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0xb508000
  physical_start_addr: 0xb508000
  partition_size: 0x169a000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS15
  partition_name: metadata
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0xcba2000
  physical_start_addr: 0xcba2000
  partition_size: 0x2000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS16
  partition_name: nvcfg
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0xeba2000
  physical_start_addr: 0xeba2000
  partition_size: 0x2000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS17
  partition_name: nvdata
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x10ba2000
  physical_start_addr: 0x10ba2000
  partition_size: 0x4000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS18
  partition_name: protect1
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x14ba2000
  physical_start_addr: 0x14ba2000
  partition_size: 0x800000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS19
  partition_name: protect2
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x153a2000
  physical_start_addr: 0x153a2000
  partition_size: 0xc5e000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS20
  partition_name: seccfg
  file_name: seccfg.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x16000000
  physical_start_addr: 0x16000000
  partition_size: 0x800000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS21
  partition_name: sec1
  file_name: sec1.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x16800000
  physical_start_addr: 0x16800000
  partition_size: 0x200000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS22
  partition_name: proinfo
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x16a00000
  physical_start_addr: 0x16a00000
  partition_size: 0x300000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS23
  partition_name: boot_para
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x16d00000
  physical_start_addr: 0x16d00000
  partition_size: 0x1a00000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS24
  partition_name: nvram
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x18700000
  physical_start_addr: 0x18700000
  partition_size: 0x4000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: PROTECTED
  reserve: 0x00

- partition_index: SYS25
  partition_name: logo
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x1c700000
  physical_start_addr: 0x1c700000
  partition_size: 0x1000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS26
  partition_name: md1img
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x1d700000
  physical_start_addr: 0x1d700000
  partition_size: 0x8000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS27
  partition_name: spmfw
  file_name: spmfw.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x25700000
  physical_start_addr: 0x25700000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS28
  partition_name: scp1
  file_name: scp.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x25800000
  physical_start_addr: 0x25800000
  partition_size: 0x600000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS29
  partition_name: scp2
  file_name: scp.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x25e00000
  physical_start_addr: 0x25e00000
  partition_size: 0x600000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS30
  partition_name: sspm_1
  file_name: sspm.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x26400000
  physical_start_addr: 0x26400000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS31
  partition_name: sspm_2
  file_name: sspm.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x26500000
  physical_start_addr: 0x26500000
  partition_size: 0x100000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS32
  partition_name: gz1
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x26600000
  physical_start_addr: 0x26600000
  partition_size: 0x1000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS33
  partition_name: gz2
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x27600000
  physical_start_addr: 0x27600000
  partition_size: 0x1000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS34
  partition_name: lk
  file_name: lk.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x28600000
  physical_start_addr: 0x28600000
  partition_size: 0x200000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS35
  partition_name: lk2
  file_name: lk.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x28800000
  physical_start_addr: 0x28800000
  partition_size: 0x200000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS36
  partition_name: boot
  file_name: boot.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x28a00000
  physical_start_addr: 0x28a00000
  partition_size: 0x2000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS37
  partition_name: dtbo
  file_name: dtbo.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2aa00000
  physical_start_addr: 0x2aa00000
  partition_size: 0x800000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS38
  partition_name: tee1
  file_name: tee.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2b200000
  physical_start_addr: 0x2b200000
  partition_size: 0x500000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS39
  partition_name: tee2
  file_name: tee.img
  is_download: true
  type: NORMAL_ROM
  linear_start_addr: 0x2b700000
  physical_start_addr: 0x2b700000
  partition_size: 0x900000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS40
  partition_name: super
  file_name: super.img
  is_download: true
  type: EXT4_IMG
  linear_start_addr: 0x2c000000
  physical_start_addr: 0x2c000000
  partition_size: 0x100000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS41
  partition_name: cache
  file_name: NONE
  is_download: false
  type: EXT4_IMG
  linear_start_addr: 0x12c000000
  physical_start_addr: 0x12c000000
  partition_size: 0x1b000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS42
  partition_name: userdata
  file_name: NONE
  is_download: false
  type: EXT4_IMG
  linear_start_addr: 0x147000000
  physical_start_addr: 0x147000000
  partition_size: 0x1b844f8000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: UPDATE
  reserve: 0x00

- partition_index: SYS43
  partition_name: otp
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x1ccb4f8000
  physical_start_addr: 0x1ccb4f8000
  partition_size: 0x2b00000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS44
  partition_name: flashinfo
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x1ccdff8000
  physical_start_addr: 0x1ccdff8000
  partition_size: 0x1000000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00

- partition_index: SYS45
  partition_name: sgpt
  file_name: NONE
  is_download: false
  type: NORMAL_ROM
  linear_start_addr: 0x1cceff8000
  physical_start_addr: 0x1cceff8000
  partition_size: 0x8000
  region: EMMC_USER
  storage: HW_STORAGE_EMMC
  boundary_check: true
  is_reserved: false
  operation_type: INVISIBLE
  reserve: 0x00
"""
    return content

if __name__ == "__main__":
    target_paths = [
        "/run/media/tomasztoczek/TS8667_ROOT/SP_FLASH_TOOL_RESTORE_TS8667/MT6768_Android_scatter.txt",
        "/home/tomasztoczek/Documents/GitHub/JunsunV1Plus/SP_Flash_Tool_TS8667/MT6768_Android_scatter.txt"
    ]
    
    content = generate_scatter_content()
    for p in target_paths:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write(content)
        print(f"Generated scatter file: {p}")
