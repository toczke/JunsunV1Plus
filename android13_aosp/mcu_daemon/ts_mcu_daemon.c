/*
 * ==============================================================================
 * Topway TS8667 / Junsun V1 Plus - Hardened Native MCU Daemon (ts_mcu_daemon)
 * ==============================================================================
 * Connects to on-board Topway G6-TS MCU via /dev/ttyS0 (fallback: /dev/ttyMT0/1).
 * Decodes Topway 0x2E binary protocol frames with strict XOR checksum validation.
 * Injects Linux kernel uinput key events for steering wheel controls (SWC).
 * Dispatches Android system intents using /system/bin/sh (Bionic compatible).
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
#include <sys/wait.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <sys/stat.h>

#define PROTOCOL_HEADER 0x2E
#define MCU_BAUDRATE    B115200

static const char* const SERIAL_CANDIDATES[] = {
    "/dev/ttyS0",  // Discovered in vendor libts67xhw.so (c_uartopen: /dev/ttyS%d, 0)
    "/dev/ttyMT0", // MediaTek primary hardware UART
    "/dev/ttyMT1"  // MediaTek secondary hardware UART
};

static int g_serial_fd = -1;
static int g_uinput_fd = -1;
static volatile int g_running = 1;

static void sig_handler(int sig) {
    (void)sig;
    g_running = 0;
}

/*
 * Android-native command execution using /system/bin/sh.
 * Completely avoids glibc's hardcoded dependency on non-existent /bin/sh.
 */
static void android_exec(const char* cmd) {
    if (!cmd || !*cmd) return;
    pid_t pid = fork();
    if (pid == 0) {
        // Child process
        const char* sh_path = "/system/bin/sh";
        if (access(sh_path, X_OK) != 0) {
            sh_path = "/bin/sh"; // Fallback for host testing
        }
        execl(sh_path, "sh", "-c", cmd, (char*)NULL);
        _exit(127);
    } else if (pid > 0) {
        // Detach child / reap asynchronously via waitpid with WNOHANG
        int status;
        waitpid(pid, &status, WNOHANG);
    }
}

// -----------------------------------------------------------------------------
// Linux uinput Virtual Keyboard Setup
// -----------------------------------------------------------------------------
static int init_uinput(void) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        fd = open("/dev/input/uinput", O_WRONLY | O_NONBLOCK);
    }
    if (fd < 0) {
        perror("[ts_mcu_daemon] Failed to open /dev/uinput");
        return -1;
    }

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);

    // Register automotive SWC keys
    static const int keys[] = {
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
    usetup.id.vendor  = 0x18d1; // Google Inc.
    usetup.id.product = 0x2026;
    strncpy(usetup.name, "Topway TS8667 Automotive SWC", sizeof(usetup.name) - 1);

    if (ioctl(fd, UI_DEV_SETUP, &usetup) < 0) {
        perror("[ts_mcu_daemon] UI_DEV_SETUP failed");
        close(fd);
        return -1;
    }

    if (ioctl(fd, UI_DEV_CREATE) < 0) {
        perror("[ts_mcu_daemon] UI_DEV_CREATE failed");
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
    if (write(fd, &ev, sizeof(ev)) != sizeof(ev)) return;

    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN;
    ev.code = SYN_REPORT;
    ev.value = 0;
    if (write(fd, &ev, sizeof(ev)) != sizeof(ev)) return;

    usleep(25000); // 25ms standard debounce duration

    // Key Release
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY;
    ev.code = keycode;
    ev.value = 0;
    if (write(fd, &ev, sizeof(ev)) != sizeof(ev)) return;

    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN;
    ev.code = SYN_REPORT;
    ev.value = 0;
    if (write(fd, &ev, sizeof(ev)) != sizeof(ev)) return;

    printf("[ts_mcu_daemon] SWC Key emitted: Linux code %d\n", keycode);
}

// -----------------------------------------------------------------------------
// Serial Port Discovery & Configuration
// -----------------------------------------------------------------------------
static int open_candidate_serial(void) {
    for (size_t i = 0; i < sizeof(SERIAL_CANDIDATES)/sizeof(SERIAL_CANDIDATES[0]); i++) {
        const char* port = SERIAL_CANDIDATES[i];
        if (access(port, R_OK | W_OK) != 0) {
            continue;
        }

        int fd = open(port, O_RDWR | O_NOCTTY | O_NDELAY);
        if (fd < 0) {
            continue;
        }

        struct termios options;
        if (tcgetattr(fd, &options) < 0) {
            close(fd);
            continue;
        }

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
        if (tcsetattr(fd, TCSANOW, &options) < 0) {
            close(fd);
            continue;
        }

        printf("[ts_mcu_daemon] Successfully connected to MCU serial port: %s @ 115200 8N1\n", port);
        return fd;
    }
    return -1;
}

// -----------------------------------------------------------------------------
// Topway Protocol Frame Handler
// -----------------------------------------------------------------------------
static int s_prev_reverse = -1;
static int s_prev_illum   = -1;

static void handle_mcu_packet(unsigned char cmd, const unsigned char* data, int len) {
    // 1. Steering Wheel Controls
    if (cmd == 0x01 || cmd == 0x02 || cmd == 0x11) {
        if (len < 1) return;
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
            default:
                printf("[ts_mcu_daemon] Unmapped SWC keycode byte: 0x%02X\n", key_val);
                break;
        }
    }
    // 2. Vehicle Telemetry & State (Reverse gear, Headlights ILLUM)
    else if (cmd == 0x10 || cmd == 0x20) {
        if (len >= 1) {
            int reverse = (data[0] & 0x01) ? 1 : 0; // Bit 0: Reverse Gear
            int illum   = (data[0] & 0x02) ? 1 : 0; // Bit 1: Headlights On

            if (reverse != s_prev_reverse) {
                s_prev_reverse = reverse;
                printf("[ts_mcu_daemon] REVERSE GEAR %s\n", reverse ? "ENGAGED" : "DISENGAGED");
                if (reverse) {
                    android_exec("/system/bin/am broadcast -a android.intent.action.BACKCAR_SERVICE --ez status true");
                } else {
                    android_exec("/system/bin/am broadcast -a android.intent.action.BACKCAR_SERVICE --ez status false");
                }
            }

            if (illum != s_prev_illum) {
                s_prev_illum = illum;
                printf("[ts_mcu_daemon] HEADLIGHTS %s -> Switching Theme\n", illum ? "ON" : "OFF");
                if (illum) {
                    android_exec("/system/bin/cmd uimode night yes");
                    android_exec("/system/bin/am broadcast -a com.topway.action.ILLUM_CHANGED --ez illum true");
                } else {
                    android_exec("/system/bin/cmd uimode night no");
                    android_exec("/system/bin/am broadcast -a com.topway.action.ILLUM_CHANGED --ez illum false");
                }
            }
        }
    }
}

// -----------------------------------------------------------------------------
// Main Event Loop with Strict Checksum Validation
// -----------------------------------------------------------------------------
int main(int argc, char** argv) {
    (void)argc; (void)argv;
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    printf("=====================================================\n");
    printf(" Topway TS8667 Automotive MCU Daemon v2.0 (Hardened) \n");
    printf("=====================================================\n");

    g_uinput_fd = init_uinput();
    if (g_uinput_fd < 0) {
        fprintf(stderr, "[ts_mcu_daemon] Warning: Operating without uinput virtual keyboard.\n");
    }

    g_serial_fd = open_candidate_serial();
    if (g_serial_fd < 0) {
        fprintf(stderr, "[ts_mcu_daemon] Serial port not accessible yet. Will retry in background...\n");
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
            g_serial_fd = open_candidate_serial();
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
                case 0: // Header Synchronization
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
                case 2: // Command Byte
                    packet_cmd = b;
                    chk_calc += b;
                    data_idx = 0;
                    if (packet_len > 1) {
                        state = 3;
                    } else {
                        state = 4;
                    }
                    break;
                case 3: // Data Payload
                    if (data_idx < (int)sizeof(packet_data)) {
                        packet_data[data_idx++] = b;
                        chk_calc += b;
                    }
                    if (data_idx >= (packet_len - 1)) {
                        state = 4;
                    }
                    break;
                case 4: // Strict Checksum Verification (NO UNCONDITIONAL BYPASS)
                    chk_calc = (unsigned char)(chk_calc ^ 0xFF);
                    if (chk_calc == b) {
                        handle_mcu_packet(packet_cmd, packet_data, data_idx);
                    } else {
                        fprintf(stderr, "[ts_mcu_daemon] Checksum MISMATCH! Calc: 0x%02X, Received: 0x%02X (Cmd: 0x%02X, Len: %d)\n",
                                chk_calc, b, packet_cmd, packet_len);
                    }
                    state = 0; // Reset state machine to wait for next header
                    break;
            }
        }
    }

    if (g_serial_fd >= 0) close(g_serial_fd);
    if (g_uinput_fd >= 0) {
        ioctl(g_uinput_fd, UI_DEV_DESTROY);
        close(g_uinput_fd);
    }

    printf("[ts_mcu_daemon] Terminated cleanly.\n");
    return 0;
}
