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

static const char* g_forced_port = NULL;
static int g_allow_fallback = 0;
static int g_serial_fd = -1;
static int g_uinput_fd = -1;
static volatile int g_running = 1;

static void sig_handler(int sig) {
    (void)sig;
    g_running = 0;
}

/*
 * Android-native process execution with fixed arguments (NO SHELL / NO INJECTION).
 * Avoids /bin/sh or /system/bin/sh entirely, preventing command injection vulnerabilities.
 */
static void spawn_cmd(const char* file, char* const argv[]) {
    if (!file || !argv) return;
    pid_t pid = fork();
    if (pid == 0) {
        // Child process: execute binary directly with explicit arguments
        execv(file, argv);
        _exit(127);
    } else if (pid > 0) {
        int status;
        waitpid(pid, &status, WNOHANG);
    }
}

static void send_backcar_broadcast(int reverse_engaged) {
    char* const argv[] = {
        (char*)"/system/bin/am",
        (char*)"broadcast",
        (char*)"-a",
        (char*)"android.intent.action.BACKCAR_SERVICE",
        (char*)"--ez",
        (char*)"status",
        (char*)(reverse_engaged ? "true" : "false"),
        NULL
    };
    spawn_cmd("/system/bin/am", argv);
}

static void send_illum_state(int illum_on) {
    char* const uimode_argv[] = {
        (char*)"/system/bin/cmd",
        (char*)"uimode",
        (char*)"night",
        (char*)(illum_on ? "yes" : "no"),
        NULL
    };
    spawn_cmd("/system/bin/cmd", uimode_argv);

    char* const illum_argv[] = {
        (char*)"/system/bin/am",
        (char*)"broadcast",
        (char*)"-a",
        (char*)"com.topway.action.ILLUM_CHANGED",
        (char*)"--ez",
        (char*)"illum",
        (char*)(illum_on ? "true" : "false"),
        NULL
    };
    spawn_cmd("/system/bin/am", illum_argv);
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
// Serial Port Configuration & Discovery
// -----------------------------------------------------------------------------
static int configure_serial_fd(int fd) {
    struct termios options;
    if (tcgetattr(fd, &options) < 0) return -1;

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
    if (tcsetattr(fd, TCSANOW, &options) < 0) return -1;
    return 0;
}

static int open_candidate_serial(void) {
    if (g_forced_port) {
        if (access(g_forced_port, R_OK | W_OK) != 0) return -1;
        int fd = open(g_forced_port, O_RDWR | O_NOCTTY | O_NDELAY);
        if (fd < 0) return -1;
        if (configure_serial_fd(fd) < 0) {
            close(fd);
            return -1;
        }
        printf("[ts_mcu_daemon] Connected to forced MCU port: %s @ 115200 8N1\n", g_forced_port);
        return fd;
    }

    // Default: strictly /dev/ttyS0 (proven in Topway libts67xhw.so: c_uartopen: /dev/ttyS%d, 0)
    const char* default_port = "/dev/ttyS0";
    if (access(default_port, R_OK | W_OK) == 0) {
        int fd = open(default_port, O_RDWR | O_NOCTTY | O_NDELAY);
        if (fd >= 0) {
            if (configure_serial_fd(fd) == 0) {
                printf("[ts_mcu_daemon] Connected to primary Topway MCU port: %s @ 115200 8N1\n", default_port);
                return fd;
            }
            close(fd);
        }
    }

    // Only attempt fallback if explicitly authorized via command line (--allow-fallback)
    if (g_allow_fallback) {
        const char* fallback_port = "/dev/ttyMT1";
        if (access(fallback_port, R_OK | W_OK) == 0) {
            int fd = open(fallback_port, O_RDWR | O_NOCTTY | O_NDELAY);
            if (fd >= 0) {
                if (configure_serial_fd(fd) == 0) {
                    printf("[ts_mcu_daemon] Connected to fallback MCU port: %s @ 115200 8N1\n", fallback_port);
                    return fd;
                }
                close(fd);
            }
        }
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
                send_backcar_broadcast(reverse);
            }

            if (illum != s_prev_illum) {
                s_prev_illum = illum;
                printf("[ts_mcu_daemon] HEADLIGHTS %s -> Switching Theme\n", illum ? "ON" : "OFF");
                send_illum_state(illum);
            }
        }
    }
}

// -----------------------------------------------------------------------------
// Topway Protocol State Machine Parser (Modular & Unit-Testable)
// -----------------------------------------------------------------------------
typedef struct {
    int state; // 0=Wait Header, 1=Len, 2=Cmd, 3=Data, 4=Chk
    unsigned char packet_len;
    unsigned char packet_cmd;
    unsigned char packet_data[128];
    int data_idx;
    unsigned char chk_calc;
} mcu_parser_t;

/*
 * Returns:
 *   1  : Successfully decoded a complete, checksum-verified packet.
 *   0  : Byte consumed, awaiting further packet bytes.
 *  -1  : Checksum verification failure (packet rejected).
 */
static int mcu_parser_feed(mcu_parser_t* p, unsigned char b, unsigned char* out_cmd, unsigned char* out_data, int* out_len) {
    if (!p) return 0;
    switch (p->state) {
        case 0: // Header Synchronization
            if (b == PROTOCOL_HEADER) {
                p->state = 1;
                p->chk_calc = 0;
            }
            return 0;
        case 1: // Length
            if (b == 0 || b > sizeof(p->packet_data) + 1) {
                p->state = 0;
                return -1;
            }
            p->packet_len = b;
            p->chk_calc += b;
            p->state = 2;
            return 0;
        case 2: // Command Byte
            p->packet_cmd = b;
            p->chk_calc += b;
            p->data_idx = 0;
            if (p->packet_len > 1) {
                p->state = 3;
            } else {
                p->state = 4;
            }
            return 0;
        case 3: // Data Payload
            p->packet_data[p->data_idx++] = b;
            p->chk_calc += b;
            if (p->data_idx >= (p->packet_len - 1)) {
                p->state = 4;
            }
            return 0;
        case 4: // Strict Checksum Verification: (sum ^ 0xFF) == received
            p->chk_calc = (unsigned char)(p->chk_calc ^ 0xFF);
            p->state = 0; // Reset state machine to wait for next header
            if (p->chk_calc == b) {
                if (out_cmd) *out_cmd = p->packet_cmd;
                if (out_len) *out_len = p->data_idx;
                if (out_data && p->data_idx > 0) {
                    memcpy(out_data, p->packet_data, p->data_idx);
                }
                return 1;
            } else {
                return -1;
            }
    }
    p->state = 0;
    return 0;
}

// -----------------------------------------------------------------------------
// Main Event Loop
// -----------------------------------------------------------------------------
int main(int argc, char** argv) {
    int dry_run = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--port") == 0 && i + 1 < argc) {
            g_forced_port = argv[++i];
        } else if (strcmp(argv[i], "--allow-fallback") == 0) {
            g_allow_fallback = 1;
        } else if (strcmp(argv[i], "--dry-run") == 0) {
            dry_run = 1;
        }
    }

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    printf("=====================================================\n");
    printf(" Topway TS8667 Automotive MCU Daemon v2.0 (Hardened) \n");
    printf("=====================================================\n");

    if (dry_run) {
        printf("[ts_mcu_daemon] [DRY-RUN] Validating parser and syntax without hardware...\n");
        // Test dry-run packet feed
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        // Valid frame: 0x2E, Len=2, Cmd=1, Data=1, Chk = (2+1+1)^0xFF = 0xFB
        unsigned char test_frame[] = { 0x2E, 0x02, 0x01, 0x01, 0xFB };
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        int res = 0;
        for (size_t i = 0; i < sizeof(test_frame); i++) {
            res = mcu_parser_feed(&parser, test_frame[i], &cmd, data, &len);
        }
        if (res == 1 && cmd == 0x01 && len == 1 && data[0] == 0x01) {
            printf("[ts_mcu_daemon] [DRY-RUN] Test frame checksum verification: PASSED (Cmd: 0x%02X, Data: 0x%02X)\n", cmd, data[0]);
            return 0;
        } else {
            fprintf(stderr, "[-] [DRY-RUN] Test frame checksum verification: FAILED\n");
            return 1;
        }
    }

    g_uinput_fd = init_uinput();
    if (g_uinput_fd < 0) {
        fprintf(stderr, "[ts_mcu_daemon] Warning: Operating without uinput virtual keyboard.\n");
    }

    g_serial_fd = open_candidate_serial();
    if (g_serial_fd < 0) {
        fprintf(stderr, "[ts_mcu_daemon] Serial port (/dev/ttyS0) not accessible yet. Will retry in background...\n");
    }

    unsigned char buf[256];
    mcu_parser_t parser;
    memset(&parser, 0, sizeof(parser));

    unsigned char packet_cmd = 0;
    unsigned char packet_data[128];
    int packet_len = 0;

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
            int ret = mcu_parser_feed(&parser, buf[i], &packet_cmd, packet_data, &packet_len);
            if (ret == 1) {
                handle_mcu_packet(packet_cmd, packet_data, packet_len);
            } else if (ret == -1) {
                fprintf(stderr, "[ts_mcu_daemon] Checksum MISMATCH! Packet discarded.\n");
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
