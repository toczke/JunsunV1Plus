/*
 * ==============================================================================
 * Topway TS8667 - Automotive CPU Thermal Fan Governor (fan_governor)
 * ==============================================================================
 * Monitors MediaTek MT6768 junction temperature from /sys/class/thermal/thermal_zone0/temp.
 * Controls active PWM cooling fan via /sys/class/leds/fan/brightness.
 * Prevents thermal throttling during navigation & heavy automotive workloads.
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>

#define TEMP_PATH "/sys/class/thermal/thermal_zone0/temp"
#define FAN_PATH  "/sys/class/leds/fan/brightness"

static volatile int g_running = 1;
static void sig_handler(int sig) { (void)sig; g_running = 0; }

static int read_cpu_temp() {
    FILE* f = fopen(TEMP_PATH, "r");
    if (!f) return -1;
    int temp = 0;
    if (fscanf(f, "%d", &temp) != 1) temp = -1;
    fclose(f);
    return temp;
}

static void set_fan_speed(int pwm) {
    FILE* f = fopen(FAN_PATH, "w");
    if (!f) return;
    fprintf(f, "%d\n", pwm);
    fclose(f);
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    printf("[fan_governor] Starting Topway TS8667 Thermal Protection Daemon...\n");

    int last_pwm = -1;

    while (g_running) {
        int temp = read_cpu_temp();
        if (temp > 0) {
            int target_pwm = 0;
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

            if (target_pwm != last_pwm) {
                set_fan_speed(target_pwm);
                printf("[fan_governor] Temp: %d C -> Fan PWM set to %d/255\n", temp / 1000, target_pwm);
                last_pwm = target_pwm;
            }
        }
        sleep(5);
    }

    set_fan_speed(0);
    printf("[fan_governor] Stopped.\n");
    return 0;
}
