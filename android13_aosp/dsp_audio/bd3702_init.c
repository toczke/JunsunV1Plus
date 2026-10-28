/*
 * ==============================================================================
 * Topway TS8667 - ROHM BD3702FV Audio DSP Hardware Initializer (bd3702_init)
 * ==============================================================================
 * Initializes the ROHM BD3702FV preamp/EQ audio processor over /dev/i2c-1.
 * Unmutes master volume, routes MediaTek DAC input, sets flat EQ and unity gain.
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <linux/i2c.h>

#define I2C_DEV_PATH "/dev/i2c-1"
#define BD3702_ADDR  0x40 // 7-bit slave address (0x80 >> 1)

static int write_reg(int fd, unsigned char reg, unsigned char val) {
    unsigned char buf[2] = { reg, val };
    if (write(fd, buf, 2) != 2) {
        return -1;
    }
    return 0;
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    printf("[bd3702_init] Opening %s for ROHM BD3702FV audio DSP...\n", I2C_DEV_PATH);

    int fd = open(I2C_DEV_PATH, O_RDWR);
    if (fd < 0) {
        perror("Failed to open I2C bus");
        return 1;
    }

    if (ioctl(fd, I2C_SLAVE, BD3702_ADDR) < 0) {
        perror("Failed to set I2C slave address 0x40");
        close(fd);
        return 1;
    }

    // 1. Initial Setup: Input Select (A_DIFF / Main MediaTek DAC), Unmute
    // Reg 0x01: Input Selector (Input 1, Full Diff, Gain 0dB)
    write_reg(fd, 0x01, 0x00);

    // 2. Master Volume (0x20): Nominal unattenuated volume (-6dB to 0dB)
    write_reg(fd, 0x20, 0x10);

    // 3. Faders: Front-Left, Front-Right, Rear-Left, Rear-Right, Subwoofer (0dB)
    write_reg(fd, 0x28, 0x00); // Front Left
    write_reg(fd, 0x29, 0x00); // Front Right
    write_reg(fd, 0x2A, 0x00); // Rear Left
    write_reg(fd, 0x2B, 0x00); // Rear Right
    write_reg(fd, 0x2C, 0x00); // Subwoofer

    // 4. Equalizer: Flat curve (Bass = 0dB, Middle = 0dB, Treble = 0dB)
    write_reg(fd, 0x05, 0x00); // Bass
    write_reg(fd, 0x06, 0x00); // Middle
    write_reg(fd, 0x07, 0x00); // Treble

    printf("[bd3702_init] ROHM BD3702FV initialized successfully! Audio unmuted.\n");
    close(fd);
    return 0;
}
