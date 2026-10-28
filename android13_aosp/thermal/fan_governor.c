/*
 * ==============================================================================
 * Topway TS8667 - Automotive CPU Thermal Fan Governor (Hardened)
 * ==============================================================================
 * Monitors MediaTek MT6768 junction temperature from /sys/class/thermal/thermal_zone0/temp.
 * Controls active PWM cooling fan via /sys/class/leds/fan/brightness (0-255 PWM).
 * Implements failsafe fallback: if temperature reading fails, maintains a safe
 * medium fan speed (~60%) instead of shutting off to protect dashboard hardware.
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>

#define TEMP_PATH "/sys/class/thermal/thermal_zone0/temp"
#define FAN_PATH  "/sys/class/leds/fan/brightness"

#define FAILSAFE_PWM 160 // ~60% PWM if sensor is unreadable

static volatile int g_running = 1;
static void sig_handler(int sig) { (void)sig; g_running = 0; }

static int read_cpu_temp(int dry_run) {
    if (dry_run) {
        return 50000; // Simulated 50.0 C
    }
    FILE* f = fopen(TEMP_PATH, "r");
    if (!f) return -1;
    int temp = 0;
    if (fscanf(f, "%d", &temp) != 1) temp = -1;
    fclose(f);
    return temp;
}

static int set_fan_speed(int pwm, int dry_run) {
    if (dry_run) {
        printf("[fan_governor] [DRY-RUN] set fan PWM = %d/255\n", pwm);
        return 0;
    }
    FILE* f = fopen(FAN_PATH, "w");
    if (!f) return -1;
    fprintf(f, "%d\n", pwm);
    fclose(f);
    return 0;
}

int main(int argc, char** argv) {
    int dry_run = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--dry-run") == 0) {
            dry_run = 1;
        }
    }

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    printf("=====================================================\n");
    printf(" Topway TS8667 Thermal Protection Governor v2.0     \n");
    printf("=====================================================\n");

    int last_pwm = -1;
    int sensor_error_count = 0;
    int fan_hw_present = 1;

    if (!dry_run && access(FAN_PATH, F_OK) != 0) {
        printf("[fan_governor] Notice: %s does not exist on this unit.\n", FAN_PATH);
        printf("[fan_governor] Topway TS8667 uses passive aluminum chassis heatsink cooling by default.\n");
        printf("[fan_governor] Running in thermal monitoring mode (no PWM hardware control active).\n");
        fan_hw_present = 0;
    }

    while (g_running) {
        int temp = read_cpu_temp(dry_run);
        int target_pwm = FAILSAFE_PWM;

        if (temp > 0) {
            sensor_error_count = 0;
            // Temp in millidegrees C
            if (temp >= 65000) {
                target_pwm = 255; // 100% full speed
            } else if (temp >= 52000) {
                target_pwm = 160; // ~60% medium quiet speed
            } else if (temp >= 45000) {
                target_pwm = 90;  // ~35% low idle speed
            } else {
                target_pwm = 0;   // Fan off
            }
        } else {
            sensor_error_count++;
            if (sensor_error_count >= 3) {
                if (fan_hw_present) {
                    fprintf(stderr, "[fan_governor] Warning: Thermal sensor read failed! Engaging failsafe PWM (%d/255)\n", FAILSAFE_PWM);
                }
                target_pwm = FAILSAFE_PWM;
            }
        }

        if (target_pwm != last_pwm) {
            if (fan_hw_present || dry_run) {
                set_fan_speed(target_pwm, dry_run);
            }
            if (temp > 0) {
                printf("[fan_governor] CPU Temp: %d C%s\n", temp / 1000,
                       fan_hw_present ? " (PWM updated)" : " (Passive heatsink)");
            }
            last_pwm = target_pwm;
        }

        if (dry_run) break;
        sleep(5);
    }

    if (!dry_run) {
        set_fan_speed(0, dry_run);
    }
    printf("[fan_governor] Terminated cleanly.\n");
    return 0;
}
