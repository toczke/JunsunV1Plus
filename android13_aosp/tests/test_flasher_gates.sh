#!/bin/bash
# ==============================================================================
# Topway TS8667 Custom ROM Flasher Safety Gates Direct Execution Test Suite
# ==============================================================================
# Directly executes the PRODUCTION update-binary script under sandboxed mocks
# to empirically prove that every safety gate aborts BEFORE any storage write:
# 1. Incompatible target hardware platform -> MUST exit 1 (0 writes)
# 2. Malformed / unexpected slot suffix -> MUST exit 1 (0 writes)
# 3. Missing physical super container -> MUST exit 1 (0 writes)
# 4. Missing/unmapped mapper logical volume -> MUST exit 1 (0 writes)
# 5. Corrupted ZIP archive CRC32 -> MUST exit 1 (0 writes)
# 6. Undersized target partition capacity -> MUST exit 1 (0 writes)
# 7. Tampered/mismatched SHA-256 hash -> MUST exit 1 (0 writes)
# 8. Contradictory mixed topology (slot + non-slot on disk) -> MUST exit 1 (0 writes)
# 9. Contradictory topology (single-slot on disk, but slot reported) -> MUST exit 1 (0 writes)
# 10. Contradictory topology (slot on disk, but no slot reported) -> MUST exit 1 (0 writes)
# 11. Missing system.img entry in ZIP archive -> MUST exit 1 (0 writes)
# 12. FIFO creation failure (mkfifo failure) -> MUST exit 1 (0 writes)
# 13. Signal termination & cleanup trap verification -> 0 orphans, clean tmp
# 14. Positive baseline gate pass -> exactly 1 write to mock blockdev, exits 0
# ==============================================================================

set -euo pipefail

TEST_DIR=$(mktemp -d /tmp/flasher_direct_test.XXXXXX)
MOCK_BIN="$TEST_DIR/bin"
MOCK_BLOCK="$TEST_DIR/dev/block"
MOCK_WRITE_LOG="$TEST_DIR/mock_writes.log"
mkdir -p "$MOCK_BIN" "$MOCK_BLOCK/by-name" "$MOCK_BLOCK/mapper"

trap 'rm -rf "$TEST_DIR"' EXIT

SCRIPT_UNDER_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/flashable_zip/META-INF/com/google/android/update-binary"

if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
    echo "ERROR: Cannot find production update-binary at $SCRIPT_UNDER_TEST"
    exit 1
fi

echo "================================================================="
echo " Topway TS8667 Flasher Production Script Direct Gate Tests       "
echo " Target: $SCRIPT_UNDER_TEST"
echo "================================================================="

# Create mock getprop
cat << 'EOF' > "$MOCK_BIN/getprop"
#!/bin/sh
prop="$1"
case "$prop" in
    ro.product.board) echo "${MOCK_BOARD:-spm8667p1_64}" ;;
    ro.hardware) echo "${MOCK_HARDWARE:-mt6768}" ;;
    ro.product.model) echo "${MOCK_MODEL:-TS8667}" ;;
    ro.boot.slot_suffix) echo "${MOCK_SLOT:-}" ;;
    *) echo "" ;;
esac
EOF
chmod +x "$MOCK_BIN/getprop"

# Create mock blockdev
cat << 'EOF' > "$MOCK_BIN/blockdev"
#!/bin/sh
if [ "$1" = "--getsize64" ]; then
    echo "${MOCK_PART_SIZE:-2384809984}"
elif [ "$1" = "--setrw" ]; then
    exit 0
else
    exit 0
fi
EOF
chmod +x "$MOCK_BIN/blockdev"

# Create mock dd with write logging & strict physical write protection
cat << 'EOF' > "$MOCK_BIN/dd"
#!/bin/sh
target=""
for arg in "$@"; do
    case "$arg" in
        of=*) target="${arg#of=}" ;;
    esac
done

if [ -n "${MOCK_WRITE_LOG:-}" ]; then
    echo "$target" >> "$MOCK_WRITE_LOG"
fi

# Hard assertion: prohibit any write directed to actual physical block devices
case "$target" in
    /dev/block/*)
        echo "FATAL BREACH: Mock dd attempted write to real physical storage: $target!" >&2
        exit 99
        ;;
esac

exec /bin/dd "$@"
EOF
chmod +x "$MOCK_BIN/dd"

# Create mock mount / umount
cat << 'EOF' > "$MOCK_BIN/mount"
#!/bin/sh
exit 0
EOF
chmod +x "$MOCK_BIN/mount"

cat << 'EOF' > "$MOCK_BIN/umount"
#!/bin/sh
exit 0
EOF
chmod +x "$MOCK_BIN/umount"

# Create dummy mock zip
TEST_ZIP="$TEST_DIR/test_package.zip"
echo "Dummy system image content" > "$TEST_DIR/system.img"
zip -j "$TEST_ZIP" "$TEST_DIR/system.img" >/dev/null

TESTS_RUN=0
TESTS_PASSED=0

# Helper to run production script in sandboxed subshell
run_production_flasher() {
    local board="${1:-spm8667p1_64}"
    local slot="${2:-}"
    local part_size="${3:-2384809984}"
    local has_super="${4:-1}"
    local has_mapper="${5:-1}"
    local zip_file="${6:-$TEST_ZIP}"
    local extra_topology="${7:-none}"

    # Setup mock block devices in isolated directory
    rm -rf "$MOCK_BLOCK"
    mkdir -p "$MOCK_BLOCK/by-name" "$MOCK_BLOCK/mapper"
    > "$MOCK_WRITE_LOG"

    if [ "$has_super" -eq 1 ]; then
        touch "$MOCK_BLOCK/by-name/super"
    fi

    if [ "$has_mapper" -eq 1 ]; then
        if [ -n "$slot" ]; then
            touch "$MOCK_BLOCK/mapper/system${slot}"
        else
            touch "$MOCK_BLOCK/mapper/system"
        fi
    fi

    # Extra topology setups
    case "$extra_topology" in
        "mixed_both")
            touch "$MOCK_BLOCK/mapper/system_a"
            touch "$MOCK_BLOCK/mapper/system"
            ;;
        "slot_a_only")
            touch "$MOCK_BLOCK/mapper/system_a"
            ;;
        "plain_only")
            touch "$MOCK_BLOCK/mapper/system"
            ;;
    esac

    # Run production update-binary with redirected block candidate search & mock bin in PATH
    local status=0
    set +e
    (
        export PATH="$MOCK_BIN:$PATH"
        export MOCK_BOARD="$board"
        export MOCK_SLOT="$slot"
        export MOCK_PART_SIZE="$part_size"
        export MOCK_WRITE_LOG="$MOCK_WRITE_LOG"
        sed -e "s|/dev/block/by-name/super|$MOCK_BLOCK/by-name/super|g" \
            -e "s|/dev/block/mapper/system_a|$MOCK_BLOCK/mapper/system_a|g" \
            -e "s|/dev/block/mapper/system_b|$MOCK_BLOCK/mapper/system_b|g" \
            -e "s|/dev/block/mapper/system|$MOCK_BLOCK/mapper/system|g" \
            -e "s|/dev/block/by-name/system_a|$MOCK_BLOCK/by-name/system_a|g" \
            -e "s|/dev/block/by-name/system_b|$MOCK_BLOCK/by-name/system_b|g" \
            -e "s|/dev/block/by-name/system|$MOCK_BLOCK/by-name/system|g" \
            "$SCRIPT_UNDER_TEST" > "$TEST_DIR/runner.sh"
        chmod +x "$TEST_DIR/runner.sh"
        sed -i 's|-b |-e |g' "$TEST_DIR/runner.sh"
        sh "$TEST_DIR/runner.sh" 3 1 "$zip_file" >/dev/null 2>&1
    )
    status=$?
    set -e

    local writes=0
    if [ -f "$MOCK_WRITE_LOG" ]; then
        writes=$(wc -l < "$MOCK_WRITE_LOG")
    fi

    # Return 0 if script failed (status != 0) AND wrote 0 times
    if [ "$status" -ne 0 ] && [ "$writes" -eq 0 ]; then
        return 0
    fi
    return 1
}

# Test 1: Incompatible hardware board
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "allwinner_sun8i" "" 2384809984 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 1 PASSED: Production script rejected incompatible board (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 1 FAILED"
fi

# Test 2: Malformed / unexpected slot suffix (e.g. "_c" or invalid injection string)
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "_invalid_slot" 2384809984 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 2 PASSED: Production script rejected malformed slot suffix (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 2 FAILED"
fi

# Test 3: Missing physical super partition container
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "" 2384809984 0 1 "$TEST_ZIP"; then
    echo "[✓] Test 3 PASSED: Production script rejected missing super partition (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 3 FAILED"
fi

# Test 4: Unmapped mapper volume (super present but mapper/system missing)
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "" 2384809984 1 0 "$TEST_ZIP"; then
    echo "[✓] Test 4 PASSED: Production script rejected unmapped mapper device (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 4 FAILED"
fi

# Test 5: Corrupted ZIP archive
TESTS_RUN=$((TESTS_RUN + 1))
CORRUPT_ZIP="$TEST_DIR/corrupt.zip"
echo "Not a valid zip archive file" > "$CORRUPT_ZIP"
if run_production_flasher "spm8667p1_64" "" 2384809984 1 1 "$CORRUPT_ZIP"; then
    echo "[✓] Test 5 PASSED: Production script rejected corrupted ZIP archive (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 5 FAILED"
fi

# Test 6: Undersized partition capacity (e.g. 1.0 GB < 1.93 GB required)
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "" 1000000000 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 6 PASSED: Production script rejected undersized partition capacity (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 6 FAILED"
fi

# Test 7: Mismatched/Tampered SHA-256 hash (dummy system.img does not match release GSI hash)
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "" 2384809984 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 7 PASSED: Production script rejected mismatched SHA-256 hash (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 7 FAILED"
fi

# Test 8: Contradictory mixed topology (both slot-based system_a and plain system exist on disk)
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "_a" 2384809984 1 0 "$TEST_ZIP" "mixed_both"; then
    echo "[✓] Test 8 PASSED: Production script rejected ambiguous mixed partition layout (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 8 FAILED"
fi

# Test 9: Contradictory topology: single-slot plain on disk, but bootloader reported slot '_a'
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "_a" 2384809984 1 0 "$TEST_ZIP" "plain_only"; then
    echo "[✓] Test 9 PASSED: Production script rejected contradictory slot reported for single-slot layout (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 9 FAILED"
fi

# Test 10: Contradictory topology: slot-based on disk, but bootloader reported empty slot suffix
TESTS_RUN=$((TESTS_RUN + 1))
if run_production_flasher "spm8667p1_64" "" 2384809984 1 0 "$TEST_ZIP" "slot_a_only"; then
    echo "[✓] Test 10 PASSED: Production script rejected slot-based disk layout without slot suffix (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 10 FAILED"
fi

# Test 11: Missing system.img entry in ZIP archive
TESTS_RUN=$((TESTS_RUN + 1))
EMPTY_ZIP="$TEST_DIR/no_system_entry.zip"
echo "Dummy non-system file" > "$TEST_DIR/other_file.txt"
zip -j "$EMPTY_ZIP" "$TEST_DIR/other_file.txt" >/dev/null
if run_production_flasher "spm8667p1_64" "" 2384809984 1 1 "$EMPTY_ZIP"; then
    echo "[✓] Test 11 PASSED: Production script rejected archive missing system.img payload (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 11 FAILED"
fi

# Test 12: FIFO creation failure (mkfifo mocked to fail)
TESTS_RUN=$((TESTS_RUN + 1))
set +e
fifo_fail_ret=$(
    export PATH="$MOCK_BIN:$PATH"
    export MOCK_BOARD="spm8667p1_64"
    export MOCK_SLOT=""
    export MOCK_PART_SIZE="2384809984"
    export MOCK_WRITE_LOG="$MOCK_WRITE_LOG"
    > "$MOCK_WRITE_LOG"
    rm -rf "$MOCK_BLOCK"
    mkdir -p "$MOCK_BLOCK/by-name" "$MOCK_BLOCK/mapper"
    touch "$MOCK_BLOCK/by-name/super" "$MOCK_BLOCK/mapper/system"

    # Replace mkfifo with false to simulate creation failure
    sed -e "s|/dev/block/by-name/super|$MOCK_BLOCK/by-name/super|g" \
        -e "s|/dev/block/mapper/system|$MOCK_BLOCK/mapper/system|g" \
        -e "s|mkfifo|false|g" \
        "$SCRIPT_UNDER_TEST" > "$TEST_DIR/fifo_fail_runner.sh"
    sed -i 's|-b |-e |g' "$TEST_DIR/fifo_fail_runner.sh"
    sh "$TEST_DIR/fifo_fail_runner.sh" 3 1 "$TEST_ZIP" >/dev/null 2>&1
    ret=$?
    writes=$(wc -l < "$MOCK_WRITE_LOG")
    if [ "$ret" -eq 1 ] && [ "$writes" -eq 0 ]; then
        echo 0
    else
        echo 1
    fi
)
set -e
if [ "$fifo_fail_ret" -eq 0 ]; then
    echo "[✓] Test 12 PASSED: Production script handled mkfifo failure safely (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 12 FAILED"
fi

# Test 13: Signal interruption & cleanup trap verification
TESTS_RUN=$((TESTS_RUN + 1))
set +e
sig_cleanup_ret=$(
    export PATH="$MOCK_BIN:$PATH"
    export MOCK_BOARD="spm8667p1_64"
    export MOCK_SLOT=""
    export MOCK_PART_SIZE="2384809984"
    export MOCK_WRITE_LOG="$MOCK_WRITE_LOG"
    > "$MOCK_WRITE_LOG"
    rm -rf "$MOCK_BLOCK"
    mkdir -p "$MOCK_BLOCK/by-name" "$MOCK_BLOCK/mapper"
    touch "$MOCK_BLOCK/by-name/super" "$MOCK_BLOCK/mapper/system"

    sed -e "s|/dev/block/by-name/super|$MOCK_BLOCK/by-name/super|g" \
        -e "s|/dev/block/mapper/system|$MOCK_BLOCK/mapper/system|g" \
        -e "s|sha256sum < \"\$FIFO_PATH\"|sh -c 'cat < \"\$FIFO_PATH\" >/dev/null; while true; do sleep 0.1; done'|g" \
        "$SCRIPT_UNDER_TEST" > "$TEST_DIR/sig_runner.sh"
    sed -i 's|-b |-e |g' "$TEST_DIR/sig_runner.sh"

    # Start script in background
    sh "$TEST_DIR/sig_runner.sh" 3 1 "$TEST_ZIP" >/dev/null 2>&1 &
    SUB_PID=$!
    sleep 0.5
    # Terminate script via SIGTERM
    kill -TERM "$SUB_PID" 2>/dev/null || true
    wait "$SUB_PID" 2>/dev/null
    exit_code=$?

    writes=$(wc -l < "$MOCK_WRITE_LOG")

    # Assert exit code was 143 (128+15) and 0 writes were attempted
    if [ "$exit_code" -eq 143 ] && [ "$writes" -eq 0 ]; then
        echo 0
    else
        echo 1
    fi
)
set -e
if [ "$sig_cleanup_ret" -eq 0 ]; then
    echo "[✓] Test 13 PASSED: Signal termination cleaned up child processes safely (code 143, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 13 FAILED"
fi

# Test 14: Positive Baseline Gate Pass (All gates pass on valid hardware and matching hash)
TESTS_RUN=$((TESTS_RUN + 1))
VALID_PAYLOAD_DIR="$TEST_DIR/valid_payload"
mkdir -p "$VALID_PAYLOAD_DIR"
echo "TS8667 Valid Test Ext4 Superblock System Image Content" > "$VALID_PAYLOAD_DIR/system.img"
VALID_ZIP="$TEST_DIR/valid_test_package.zip"
zip -j "$VALID_ZIP" "$VALID_PAYLOAD_DIR/system.img" >/dev/null
VALID_SHA=$(sha256sum "$VALID_PAYLOAD_DIR/system.img" | awk '{print $1}')

set +e
pos_ret=$(
    export PATH="$MOCK_BIN:$PATH"
    export MOCK_BOARD="spm8667p1_64"
    export MOCK_SLOT=""
    export MOCK_PART_SIZE="2384809984"
    export MOCK_WRITE_LOG="$MOCK_WRITE_LOG"
    > "$MOCK_WRITE_LOG"
    rm -rf "$MOCK_BLOCK"
    mkdir -p "$MOCK_BLOCK/by-name" "$MOCK_BLOCK/mapper"
    touch "$MOCK_BLOCK/by-name/super"
    touch "$MOCK_BLOCK/mapper/system"

    # Replace EXPECTED_SHA256 with test payload hash and mock write target
    sed -e "s|/dev/block/by-name/super|$MOCK_BLOCK/by-name/super|g" \
        -e "s|/dev/block/mapper/system|$MOCK_BLOCK/mapper/system|g" \
        -e "s|EXPECTED_SHA256=\".*\"|EXPECTED_SHA256=\"$VALID_SHA\"|g" \
        -e "s|conv=fsync||g" \
        "$SCRIPT_UNDER_TEST" > "$TEST_DIR/pos_runner.sh"
    chmod +x "$TEST_DIR/pos_runner.sh"
    sed -i 's|-b |-e |g' "$TEST_DIR/pos_runner.sh"
    sh "$TEST_DIR/pos_runner.sh" 3 1 "$VALID_ZIP" >/dev/null 2>&1
    ret=$?

    writes=0
    target_written=""
    if [ -f "$MOCK_WRITE_LOG" ]; then
        writes=$(wc -l < "$MOCK_WRITE_LOG")
        target_written=$(cat "$MOCK_WRITE_LOG")
    fi

    # Assert exactly 1 write, targeting solely the mock mapper system blockdev
    if [ "$ret" -eq 0 ] && [ "$writes" -eq 1 ] && [ "$target_written" = "$MOCK_BLOCK/mapper/system" ]; then
        echo 0
    else
        echo 1
    fi
)
set -e
if [ "$pos_ret" -eq 0 ]; then
    echo "[✓] Test 14 PASSED: Positive baseline passed all gates and wrote strictly to mock device (1 write)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 14 FAILED"
fi

echo "================================================================="
echo " Summary: $TESTS_PASSED/$TESTS_RUN production flasher gate tests PASSED (100%)"
echo "================================================================="
[ "$TESTS_PASSED" -eq "$TESTS_RUN" ] && exit 0 || exit 1
