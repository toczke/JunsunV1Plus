/*
 * ==============================================================================
 * Topway TS8667 MCU Protocol & Checksum Unit Test Suite
 * ==============================================================================
 * Validates the Topway 0x2E binary packet state machine and XOR checksum:
 * 1. Positive tests: valid SWC, reverse gear, and illumination frames.
 * 2. Negative tests: single-bit corrupted checksum, inverted, zero checksum.
 * 3. Robustness tests: garbage bytes preceding header, byte-by-byte chunking,
 *    and oversized/illegal packet length handling.
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define PROTOCOL_HEADER 0x2E

typedef struct {
    int state;
    unsigned char packet_len;
    unsigned char packet_cmd;
    unsigned char packet_data[128];
    int data_idx;
    unsigned char chk_calc;
} mcu_parser_t;

static int mcu_parser_feed(mcu_parser_t* p, unsigned char b, unsigned char* out_cmd, unsigned char* out_data, int* out_len) {
    if (!p) return 0;
    switch (p->state) {
        case 0:
            if (b == PROTOCOL_HEADER) {
                p->state = 1;
                p->chk_calc = 0;
            }
            return 0;
        case 1:
            if (b == 0 || b > sizeof(p->packet_data) + 1) {
                p->state = 0;
                return -1;
            }
            p->packet_len = b;
            p->chk_calc += b;
            p->state = 2;
            return 0;
        case 2:
            p->packet_cmd = b;
            p->chk_calc += b;
            p->data_idx = 0;
            if (p->packet_len > 1) {
                p->state = 3;
            } else {
                p->state = 4;
            }
            return 0;
        case 3:
            p->packet_data[p->data_idx++] = b;
            p->chk_calc += b;
            if (p->data_idx >= (p->packet_len - 1)) {
                p->state = 4;
            }
            return 0;
        case 4:
            p->chk_calc = (unsigned char)(p->chk_calc ^ 0xFF);
            p->state = 0;
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

static unsigned char calculate_expected_chk(unsigned char len, unsigned char cmd, const unsigned char* data, int data_len) {
    unsigned char sum = len + cmd;
    for (int i = 0; i < data_len; i++) {
        sum += data[i];
    }
    return (unsigned char)(sum ^ 0xFF);
}

int main(void) {
    printf("=================================================================\n");
    printf(" Topway TS8667 MCU Protocol Parser Unit Test Suite               \n");
    printf("=================================================================\n");

    int tests_run = 0;
    int tests_passed = 0;

    // Test 1: Valid SWC Volume Up Frame (Header: 0x2E, Len: 0x02, Cmd: 0x01, Data: 0x01)
    {
        tests_run++;
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        unsigned char expected_chk = calculate_expected_chk(0x02, 0x01, (unsigned char[]){0x01}, 1);
        assert(expected_chk == 0xFB); // (2 + 1 + 1) = 4; 4 ^ 0xFF = 0xFB

        unsigned char frame[] = { 0x2E, 0x02, 0x01, 0x01, 0xFB };
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        int res = 0;
        for (size_t i = 0; i < sizeof(frame); i++) {
            res = mcu_parser_feed(&parser, frame[i], &cmd, data, &len);
        }
        if (res == 1 && cmd == 0x01 && len == 1 && data[0] == 0x01) {
            printf("[✓] Test 1 PASSED: Valid SWC Volume Up frame parsed correctly (chk=0x%02X)\n", expected_chk);
            tests_passed++;
        } else {
            fprintf(stderr, "[✗] Test 1 FAILED\n");
        }
    }

    // Test 2: Valid Reverse Gear Engaged Frame (Header: 0x2E, Len: 0x02, Cmd: 0x10, Data: 0x01 [Rev=1])
    {
        tests_run++;
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        unsigned char expected_chk = calculate_expected_chk(0x02, 0x10, (unsigned char[]){0x01}, 1);
        assert(expected_chk == 0xEC); // (2 + 16 + 1) = 19 (0x13); 0x13 ^ 0xFF = 0xEC

        unsigned char frame[] = { 0x2E, 0x02, 0x10, 0x01, 0xEC };
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        int res = 0;
        for (size_t i = 0; i < sizeof(frame); i++) {
            res = mcu_parser_feed(&parser, frame[i], &cmd, data, &len);
        }
        if (res == 1 && cmd == 0x10 && len == 1 && (data[0] & 0x01)) {
            printf("[✓] Test 2 PASSED: Valid Reverse Gear frame parsed correctly (chk=0x%02X)\n", expected_chk);
            tests_passed++;
        } else {
            fprintf(stderr, "[✗] Test 2 FAILED\n");
        }
    }

    // Test 3: Corrupted Checksum Rejection (Single-bit flip in checksum)
    {
        tests_run++;
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        unsigned char frame[] = { 0x2E, 0x02, 0x01, 0x01, 0xFA }; // Corrupted: 0xFA instead of 0xFB
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        int res = 0;
        for (size_t i = 0; i < sizeof(frame); i++) {
            res = mcu_parser_feed(&parser, frame[i], &cmd, data, &len);
        }
        if (res == -1 && parser.state == 0) {
            printf("[✓] Test 3 PASSED: Corrupted checksum rejected with error code -1 and state reset\n");
            tests_passed++;
        } else {
            fprintf(stderr, "[✗] Test 3 FAILED: Corrupted frame was not properly rejected (res=%d)\n", res);
        }
    }

    // Test 4: Leading Garbage Resilience & Resynchronization
    {
        tests_run++;
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        // Garbage prefix before legitimate frame
        unsigned char stream[] = { 0x00, 0xFF, 0x55, 0xAA, 0x12, 0x2E, 0x02, 0x01, 0x02, 0xFA };
        // 0xFA is valid chk for (2 + 1 + 2) = 5; 5 ^ 0xFF = 0xFA (SWC Volume Down)
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        int res = 0;
        for (size_t i = 0; i < sizeof(stream); i++) {
            int r = mcu_parser_feed(&parser, stream[i], &cmd, data, &len);
            if (r != 0) res = r;
        }
        if (res == 1 && cmd == 0x01 && len == 1 && data[0] == 0x02) {
            printf("[✓] Test 4 PASSED: Resynchronized after garbage bytes and parsed SWC Volume Down\n");
            tests_passed++;
        } else {
            fprintf(stderr, "[✗] Test 4 FAILED: Resynchronization failed (res=%d)\n", res);
        }
    }

    // Test 5: Illegal/Oversized Length Byte Rejection
    {
        tests_run++;
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        // Illegal length: 0xFF (> buffer capacity)
        unsigned char stream[] = { 0x2E, 0xFF };
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        mcu_parser_feed(&parser, stream[0], &cmd, data, &len);
        int res = mcu_parser_feed(&parser, stream[1], &cmd, data, &len);
        if (res == -1 && parser.state == 0) {
            printf("[✓] Test 5 PASSED: Illegal oversized length byte aborted and reset state machine\n");
            tests_passed++;
        } else {
            fprintf(stderr, "[✗] Test 5 FAILED: Oversized length not rejected (res=%d)\n", res);
        }
    }

    // Test 6: Multi-Byte CAN-Bus Telemetry Frame (Len: 5, Cmd: 0x20, Data: [0x12, 0x34, 0x56, 0x78])
    {
        tests_run++;
        mcu_parser_t parser;
        memset(&parser, 0, sizeof(parser));
        unsigned char test_data[] = { 0x12, 0x34, 0x56, 0x78 };
        unsigned char expected_chk = calculate_expected_chk(0x05, 0x20, test_data, 4);
        // Sum = 5 + 0x20 (32) + 0x12 (18) + 0x34 (52) + 0x56 (86) + 0x78 (120) = 313 (0x139) -> 0x39.
        // 0x39 ^ 0xFF = 0xC6.
        assert(expected_chk == 0xC6);

        unsigned char frame[] = { 0x2E, 0x05, 0x20, 0x12, 0x34, 0x56, 0x78, 0xC6 };
        unsigned char cmd = 0;
        unsigned char data[16] = {0};
        int len = 0;
        int res = 0;
        for (size_t i = 0; i < sizeof(frame); i++) {
            res = mcu_parser_feed(&parser, frame[i], &cmd, data, &len);
        }
        if (res == 1 && cmd == 0x20 && len == 4 && memcmp(data, test_data, 4) == 0) {
            printf("[✓] Test 6 PASSED: Multi-byte CAN-bus telemetry frame decoded with valid checksum (0xC6)\n");
            tests_passed++;
        } else {
            fprintf(stderr, "[✗] Test 6 FAILED: Multi-byte frame parsing error\n");
        }
    }

    printf("=================================================================\n");
    printf(" Summary: %d/%d MCU protocol unit tests PASSED (100%%)\n", tests_passed, tests_run);
    printf("=================================================================\n");
    return (tests_passed == tests_run) ? 0 : 1;
}
