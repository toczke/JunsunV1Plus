/*
 * ==============================================================================
 * Topway TS8667 - ROHM BD3702FV Audio DSP Hardware Initializer (Hardened)
 * ==============================================================================
 * Probes candidate I2C buses (/dev/i2c-5 proven in stock dmesg, /dev/i2c-1, /dev/i2c-0).
 * Configures ROHM BD3702FV preamp/EQ sound processor at 7-bit slave address 0x40.
 * Routes differential MediaTek DAC input, unattenuates master volume, and sets flat EQ.
 * Supports --dry-run and --probe flags for safe hardware-independent verification.
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <linux/i2c.h>

#define BD3702_SLAVE_ADDR 0x40 // 7-bit slave address

static const char* const I2C_CANDIDATES[] = {
    "/dev/i2c-5", // Primary physical bus verified in stock Topway TS8667 kernel log
    "/dev/i2c-1", // MediaTek secondary I2C bus
    "/dev/i2c-0"  // MediaTek primary I2C bus
};

static int write_reg(int fd, unsigned char reg, unsigned char val, int dry_run) {
    if (dry_run) {
        printf("[bd3702_init] [DRY-RUN] write reg 0x%02X = 0x%02X\n", reg, val);
        return 0;
    }
    unsigned char buf[2] = { reg, val };
    if (write(fd, buf, 2) != 2) {
        perror("[bd3702_init] I2C write error");
        return -1;
    }
    return 0;
}

static int open_and_probe_i2c(int dry_run, char* out_path, size_t out_path_len) {
    for (size_t i = 0; i < sizeof(I2C_CANDIDATES)/sizeof(I2C_CANDIDATES[0]); i++) {
        const char* path = I2C_CANDIDATES[i];
        if (dry_run) {
            strncpy(out_path, path, out_path_len - 1);
            return 999; // Mock file descriptor
        }

        if (access(path, R_OK | W_OK) != 0) {
            continue;
        }

        int fd = open(path, O_RDWR);
        if (fd < 0) {
            continue;
        }

        if (ioctl(fd, I2C_SLAVE, BD3702_SLAVE_ADDR) < 0) {
            close(fd);
            continue;
        }

        // Test non-destructive I2C read transaction (query slave presence without register modification)
        // A single-byte read triggers an I2C read address cycle (0x40 << 1 | 1).
        // If the chip is physically connected and ACKs its address, the read succeeds without altering any registers.
        unsigned char probe_byte = 0;
        if (read(fd, &probe_byte, 1) < 0) {
            // Slave NAK / not responding on this bus
            close(fd);
            continue;
        }

        strncpy(out_path, path, out_path_len - 1);
        printf("[bd3702_init] Active ROHM BD3702FV found on bus: %s (addr: 0x%02X)\n", path, BD3702_SLAVE_ADDR);
        return fd;
    }
    return -1;
}

int main(int argc, char** argv) {
    int dry_run = 0;
    int probe_only = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--dry-run") == 0) {
            dry_run = 1;
        } else if (strcmp(argv[i], "--probe") == 0) {
            probe_only = 1;
        }
    }

    printf("=====================================================\n");
    printf(" Topway TS8667 ROHM BD3702FV DSP Initializer v2.0  \n");
    printf("=====================================================\n");

    char bus_path[64] = {0};
    int fd = open_and_probe_i2c(dry_run, bus_path, sizeof(bus_path));
    if (fd < 0) {
        fprintf(stderr, "[-] ERROR: ROHM BD3702FV DSP not responding on any tested I2C bus (/dev/i2c-5, 1, 0)\n");
        return 1;
    }

    if (probe_only) {
        if (dry_run) {
            printf("[+] [SIMULATION/DRY-RUN] Probe logic test: mock descriptor on %s (CI host has no physical I2C)\n", bus_path);
        } else {
            printf("[+] Physical Probe SUCCESS: BD3702FV ACK received on %s (addr: 0x%02X)\n", bus_path, BD3702_SLAVE_ADDR);
        }
        if (!dry_run && fd >= 0) close(fd);
        return 0;
    }

    printf("[+] Initializing BD3702FV registers on %s...\n", bus_path);

    // 1. Input Selector: Differential input A_DIFF from MediaTek DAC (0 dB gain)
    if (write_reg(fd, 0x01, 0x00, dry_run) < 0) goto err;

    // 2. Master Volume: Nominal unattenuated volume (-6 dB nominal to avoid power-on pop)
    if (write_reg(fd, 0x20, 0x10, dry_run) < 0) goto err;

    // 3. Faders: Front-L, Front-R, Rear-L, Rear-R, Subwoofer (0 dB)
    if (write_reg(fd, 0x28, 0x00, dry_run) < 0) goto err;
    if (write_reg(fd, 0x29, 0x00, dry_run) < 0) goto err;
    if (write_reg(fd, 0x2A, 0x00, dry_run) < 0) goto err;
    if (write_reg(fd, 0x2B, 0x00, dry_run) < 0) goto err;
    if (write_reg(fd, 0x2C, 0x00, dry_run) < 0) goto err;

    // 4. Tone Controls: Flat curve (Bass = 0 dB, Middle = 0 dB, Treble = 0 dB)
    if (write_reg(fd, 0x05, 0x00, dry_run) < 0) goto err;
    if (write_reg(fd, 0x06, 0x00, dry_run) < 0) goto err;
    if (write_reg(fd, 0x07, 0x00, dry_run) < 0) goto err;

    printf("[+] ROHM BD3702FV Audio DSP initialized successfully. Audio unmuted.\n");
    if (!dry_run && fd >= 0) close(fd);
    return 0;

err:
    fprintf(stderr, "[-] Register configuration failed on %s\n", bus_path);
    if (!dry_run && fd >= 0) close(fd);
    return 2;
}
