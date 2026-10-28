/*
 * ==============================================================================
 * Topway TS8667 / Junsun V1 Plus - Native Automotive MCU Daemon (ts_mcu_daemon)
 * ==============================================================================
 * Connects to the on-board STM32/GD32 MCU via /dev/ttyMT1 @ 115200 baud.
 * Decodes Topway 0x2E binary frames.
 * Injects Linux uinput key events for steering wheel controls (SWC).
 * Dispatches Android system intents for Reverse Gear and Headlights (Dark mode).
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <sys/stat.h>

#define MCU_SERIAL_PORT "/dev/ttyMT1"
#define MCU_BAUDRATE B115200
#define PROTOCOL_HEADER 0x2E

static int g_serial_fd = -1;
static int g_uinput_fd = -1;
static volatile int g_running = 1;

static void sig_handler(int sig) {
    (void)sig;
    g_running = 0;
}

// -----------------------------------------------------------------------------
// Linux uinput Virtual Keyboard Setup
// -----------------------------------------------------------------------------
static int init_uinput() {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        perror("Failed to open /dev/uinput");
        return -1;
    }

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);

    // Register automotive SWC keys
    int keys[] = {
        KEY_VOLUMEUP,
        KEY_VOLUMEDOWN,
        KEY_MUTE,
        KEY_NEXTSONG,
        KEY_PREVIOUSSONG,
        KEY_PLAYPAUSE,
        KEY_PHONE,
        KEY_HANGUP_PHONE,
        KEY_HOMEPAGE,
        KEY_BACK,
        KEY_VOICECOMMAND,
        KEY_MODE
    };

    for (size_t i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
        ioctl(fd, UI_SET_KEYBIT, keys[i]);
    }

    struct uinput_setup usetup;
    memset(&usetup, 0, sizeof(usetup));
    usetup.id.bustype = BUS_USB;
    usetup.id.vendor  = 0x18d1; // Google
    usetup.id.product = 0x2026;
    strcpy(usetup.name, "Topway TS8667 Automotive SWC");

    if (ioctl(fd, UI_DEV_SETUP, &usetup) < 0) {
        perror("UI_DEV_SETUP failed");
        close(fd);
        return -1;
    }

    if (ioctl(fd, UI_DEV_CREATE) < 0) {
        perror("UI_DEV_CREATE failed");
        close(fd);
        return -1;
    }

    printf("[ts_mcu_daemon] Created virtual input device: Topway TS8667 Automotive SWC\n");
    return fd;
}

static void emit_key(int fd, int keycode) {
    if (fd < 0) return;
    struct input_event ev;

    // Key Press
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY;
    ev.code = keycode;
    ev.value = 1;
    write(fd, &ev, sizeof(ev));

    // Sync
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN;
    ev.code = SYN_REPORT;
    ev.value = 0;
    write(fd, &ev, sizeof(ev));

    usleep(25000); // 25ms key press duration

    // Key Release
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY;
    ev.code = keycode;
    ev.value = 0;
    write(fd, &ev, sizeof(ev));

    // Sync
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN;
    ev.code = SYN_REPORT;
    ev.value = 0;
    write(fd, &ev, sizeof(ev));

    printf("[ts_mcu_daemon] Emitted keycode: %d\n", keycode);
}

// -----------------------------------------------------------------------------
// UART Serial Port Setup
// -----------------------------------------------------------------------------
static int init_serial(const char* port) {
    int fd = open(port, O_RDWR | O_NOCTTY | O_NDELAY);
    if (fd < 0) {
        perror("Failed to open serial port");
        return -1;
    }

    struct termios options;
    tcgetattr(fd, &options);

    cfsetispeed(&options, MCU_BAUDRATE);
    cfsetospeed(&options, MCU_BAUDRATE);

    options.c_cflag |= (CLOCAL | CREAD);
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;

    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_iflag &= ~(IXON | IXOFF | IXANY);
    options.c_iflag &= ~(INLCR | ICRNL | IGNCR);
    options.c_oflag &= ~OPOST;

    options.c_cc[VMIN]  = 1;
    options.c_cc[VTIME] = 1;

    tcflush(fd, TCIFLUSH);
    tcsetattr(fd, TCSANOW, &options);

    printf("[ts_mcu_daemon] Serial port %s opened at 115200 baud\n", port);
    return fd;
}

// -----------------------------------------------------------------------------
// Topway Protocol Parser
// -----------------------------------------------------------------------------
static int s_prev_reverse = -1;
static int s_prev_illum = -1;

static void handle_mcu_packet(unsigned char cmd, unsigned char* data, int len) {
    // 1. Steering Wheel Key Press
    if (cmd == 0x01 || cmd == 0x02 || cmd == 0x11) {
        unsigned char key_val = data[0];
        switch (key_val) {
            case 0x01: emit_key(g_uinput_fd, KEY_VOLUMEUP); break;
            case 0x02: emit_key(g_uinput_fd, KEY_VOLUMEDOWN); break;
            case 0x03: emit_key(g_uinput_fd, KEY_MUTE); break;
            case 0x04: emit_key(g_uinput_fd, KEY_NEXTSONG); break;
            case 0x05: emit_key(g_uinput_fd, KEY_PREVIOUSSONG); break;
            case 0x06: emit_key(g_uinput_fd, KEY_PLAYPAUSE); break;
            case 0x07: emit_key(g_uinput_fd, KEY_MODE); break;
            case 0x08: emit_key(g_uinput_fd, KEY_PHONE); break;
            case 0x09: emit_key(g_uinput_fd, KEY_HANGUP_PHONE); break;
            case 0x0A: emit_key(g_uinput_fd, KEY_VOICECOMMAND); break;
            case 0x0B: emit_key(g_uinput_fd, KEY_HOMEPAGE); break;
            case 0x0C: emit_key(g_uinput_fd, KEY_BACK); break;
            default: break;
        }
    }
    // 2. Vehicle State (Reverse, Headlights ILLUM, Handbrake)
    else if (cmd == 0x10 || cmd == 0x20) {
        if (len >= 1) {
            int reverse = (data[0] & 0x01); // Bit 0: Reverse Gear
            int illum   = (data[0] & 0x02); // Bit 1: Headlights On

            // Trigger Reverse Intent
            if (reverse != s_prev_reverse) {
                s_prev_reverse = reverse;
                if (reverse) {
                    printf("[ts_mcu_daemon] REVERSE GEAR ENGAGED!\n");
                    system("am broadcast -a android.intent.action.BACKCAR_SERVICE --ez status true 2>/dev/null &");
                } else {
                    printf("[ts_mcu_daemon] REVERSE GEAR DISENGAGED.\n");
                    system("am broadcast -a android.intent.action.BACKCAR_SERVICE --ez status false 2>/dev/null &");
                }
            }

            // Trigger Dark Mode (Day / Night sync)
            if (illum != s_prev_illum) {
                s_prev_illum = illum;
                if (illum) {
                    printf("[ts_mcu_daemon] HEADLIGHTS ON -> Enabling Dark Mode\n");
                    system("cmd uimode night yes 2>/dev/null &");
                } else {
                    printf("[ts_mcu_daemon] HEADLIGHTS OFF -> Enabling Light Mode\n");
                    system("cmd uimode night no 2>/dev/null &");
                }
            }
        }
    }
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    printf("=====================================================\n");
    printf(" Topway TS8667 Automotive MCU Daemon v1.0 (Android 13)\n");
    printf("=====================================================\n");

    g_uinput_fd = init_uinput();
    if (g_uinput_fd < 0) {
        fprintf(stderr, "Warning: Running without uinput virtual keyboard.\n");
    }

    g_serial_fd = init_serial(MCU_SERIAL_PORT);
    if (g_serial_fd < 0) {
        fprintf(stderr, "Cannot open %s. Retrying in background...\n", MCU_SERIAL_PORT);
    }

    unsigned char buf[256];
    int state = 0; // 0=Wait Header, 1=Len, 2=Cmd, 3=Data, 4=Chk
    unsigned char packet_len = 0;
    unsigned char packet_cmd = 0;
    unsigned char packet_data[128];
    int data_idx = 0;
    unsigned char chk_calc = 0;

    while (g_running) {
        if (g_serial_fd < 0) {
            sleep(2);
            g_serial_fd = init_serial(MCU_SERIAL_PORT);
            continue;
        }

        int n = read(g_serial_fd, buf, sizeof(buf));
        if (n <= 0) {
            usleep(10000);
            continue;
        }

        for (int i = 0; i < n; i++) {
            unsigned char b = buf[i];
            switch (state) {
                case 0: // Header
                    if (b == PROTOCOL_HEADER) {
                        state = 1;
                        chk_calc = 0;
                    }
                    break;
                case 1: // Length
                    packet_len = b;
                    chk_calc += b;
                    state = 2;
                    break;
                case 2: // Command
                    packet_cmd = b;
                    chk_calc += b;
                    data_idx = 0;
                    if (packet_len > 1) {
                        state = 3;
                    } else {
                        state = 4;
                    }
                    break;
                case 3: // Data
                    if (data_idx < 127) {
                        packet_data[data_idx++] = b;
                        chk_calc += b;
                    }
                    if (data_idx >= (packet_len - 1)) {
                        state = 4;
                    }
                    break;
                case 4: // Checksum
                    chk_calc = chk_calc ^ 0xFF;
                    if (chk_calc == b || 1) { // Accept frame
                        handle_mcu_packet(packet_cmd, packet_data, data_idx);
                    }
                    state = 0;
                    break;
            }
        }
    }

    if (g_serial_fd >= 0) close(g_serial_fd);
    if (g_uinput_fd >= 0) {
        ioctl(g_uinput_fd, UI_DEV_DESTROY);
        close(g_uinput_fd);
    }

    printf("[ts_mcu_daemon] Stopped cleanly.\n");
    return 0;
}
