# Chapter 11: LittleKernel (LK) Reverse Engineering & Recovery Triggers

Deep technical analysis of the Topway TS8667 (MediaTek MT6768 Helio P65) bootloader binary (`lk.img`), disassembly of boot mode resolution, and the discovery of vendor-specific recovery triggers.

---

## 1. Bootloader Binary Specifications

- **File:** `lk.img`
- **Container Format:** MediaTek MTK Image Header (`0x58881688`)
- **Header Size:** 512 bytes (`0x200`)
- **Execution Architecture:** ARMv7-A / Thumb-2 (AArch32)
- **Base Load Address:** `0x4c400000` (stripped header starts at `0x4c400000`)
- **Entry Point:** `0x4c400080` (resets in ARM mode, sets up stacks, and executes `blx 0x4c41f418` to enter `kmain` in Thumb-2)

---

## 2. Root Cause: Why `reboot recovery` Enters Fastboot

When Android initiates a recovery reboot via `reboot recovery` (or `setprop sys.powerctl reboot,recovery`), the kernel's PMIC driver writes a reboot flag into the MT6358 PMIC / RTC registers.

In LittleKernel's `boot_mode_select` routine at `0x4c403d84`:

```arm
4c403e08: bl 0x4c41a278        @ Reads PMIC register 0x5b4 via 0x4c418f50
4c403e0c: cmp r0, #0
4c403e0e: bne.n 0x4c403efe     @ If bit 13 == 1 -> JUMP!
...
4c403efe: ldr r0, = "[FASTBOOT] reboot to boot loader\n"
4c403f02: bl printf
4c403f08: movs r2, #99         @ FASTBOOT_BOOT mode = 99 (0x63)
4c403f0e: str r2, [g_boot_mode] @ Sets g_boot_mode = 99
```

Subroutine `0x4c41a278`:
```arm
4c41a282: movw r0, #1460       @ 0x5b4 (PMIC register)
4c41a292: bl 0x4c418f50        @ pmic_read(0x5b4, &val)
4c41a29a: ldrh.w r0, [sp]      @ Read 16-bit register value
4c41a2a0: ubfx r0, r0, #13, #1 @ Extract BIT 13
```

In Topway's LK build, the reboot reason received from the Android recovery reboot command triggers bit 13, causing LK to set `g_boot_mode = 99` (Fastboot).

Subsequently, Topway's OEM boot hook at `0x4c422ea0` checks:
```arm
4c422ef8: ldr r5, [g_boot_mode]
4c422efa: ldr r3, [r5, #0]
4c422efc: cmp r3, #99          @ Is it FASTBOOT?
4c422efe: beq.n 0x4c422f5e     @ If yes, bypass all recovery checks and enter Fastboot!
```

---

## 3. Discovered Topway Recovery Triggers

Topway's OEM boot code (`0x4c422ea0`) completely bypasses the standard Android AOSP `boot-recovery` BCB command. Instead, it implements two proprietary triggers:

### 3.1 Software Trigger: The `"ffup"` Flag in `misc`
Topway reads the first 4 bytes of partition `/dev/block/by-name/misc` at offset 0:
```arm
4c422f44: ldr r0, = "misc"
4c422f48: movs r2, #4          @ Read 4 bytes
4c422f4c: bl 0x4c40421c        @ partition_read("misc", 0, buf, 4)
4c422f50: ldrb.w r3, [sp, #1096]
4c422f54: cmp r3, #102         @ 'f'
4c422f56: beq.w 0x4c42306e
...
4c42306e: ldrb.w r3, [sp, #1097] @ 'f'
4c423078: ldrb.w r3, [sp, #1098] @ 'u'
4c423082: ldrb.w r3, [sp, #1099] @ 'p'
4c423088: itt eq
4c42308a: moveq r3, #2         @ RECOVERY_BOOT = 2!
4c42308c: streq r3, [g_boot_mode]
4c42308e: b.n 0x4c422f5a       @ Jump directly to mt_boot!
```

- When `"ffup"` is detected, LK sets `g_boot_mode = 2` and jumps to `0x4c422b90` (`mt_boot.c`), which invokes `mboot_android_load_recoveryimg` (`0x4c44f83c`).
- **Critical rule:** The device must be restarted with a standard, clean `reboot` (NOT `reboot recovery`), so PMIC bit 13 remains 0.

### 3.2 Hardware Trigger: Touchscreen Gestures on Boot
At `0x4c422f00`, LK calls the touchscreen polling routine `0x4c400644`:
```arm
0x4c400678: "----lk[TP] is not pressed!!\n"
0x4c400684: "----lk[TP] 5 fingers!\n"
0x4c400690: "----lk[TP] 4 fingers!\n"
```
- **4 Fingers on screen:** LK automatically writes `"ffup"` and triggers Recovery boot.
- **5 Fingers on screen:** LK writes `"cxj8"`, populates the BCB with `--wipe_data`, and boots Recovery to perform a factory wipe.

---

## 4. Boot Mode Jump Table in `app/mt_boot/mt_boot.c`

At address `0x4c422ba6`, LittleKernel routes execution based on `g_boot_mode`:
```arm
4c422ba0: ldr r3, [g_boot_mode]
4c422ba6: tbb [pc, r3]
```

| Mode ID | Name | Destination | Action |
|---|---|---|---|
| `0` | `NORMAL_BOOT` | `0x4c422cf2` | Loads `boot.img`, boots Android |
| `1` | `META_BOOT` | `0x4c422cf2` | MediaTek Meta mode |
| `2` | `RECOVERY_BOOT` | `0x4c422cac` | Calls `0x4c44f83c` (`mboot_android_load_recoveryimg`) |
| `3` | `SW_REBOOT` | `0x4c422cf2` | Software reset |
| `4` | `FACTORY_BOOT` | `0x4c422bb2` | Factory test mode |
| `7` | `ALARM_BOOT` | `0x4c422cf2` | RTC alarm wakeup |
| `99` | `FASTBOOT_BOOT`| `0x4c402ec0` | Enters USB Fastboot server |
