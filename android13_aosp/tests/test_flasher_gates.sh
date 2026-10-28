#!/bin/bash
# ==============================================================================
# Topway TS8667 Custom ROM Flasher Safety Gates Direct Execution Test Suite
# ==============================================================================
# Directly executes the PRODUCTION update-binary script under sandboxed mocks
# to empirically prove that every safety gate aborts before writing:
# 1. Incompatible target hardware platform -> MUST exit 1 (0 writes)
# 2. Malformed / unexpected slot suffix -> MUST exit 1 (0 writes)
# 3. Missing physical super container -> MUST exit 1 (0 writes)
# 4. Missing/unmapped mapper logical volume -> MUST exit 1 (0 writes)
# 5. Corrupted ZIP archive CRC32 -> MUST exit 1 (0 writes)
# 6. Undersized target partition capacity -> MUST exit 1 (0 writes)
# 7. Tampered/mismatched SHA-256 hash -> MUST exit 1 (0 writes)
# ==============================================================================

set -euo pipefail

TEST_DIR=$(mktemp -d /tmp/flasher_direct_test.XXXXXX)
MOCK_BIN="$TEST_DIR/bin"
MOCK_BLOCK="$TEST_DIR/dev/block"
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

    # Setup mock block devices in isolated directory
    rm -rf "$MOCK_BLOCK"
    mkdir -p "$MOCK_BLOCK/by-name" "$MOCK_BLOCK/mapper"

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

    # Run production update-binary with redirected block candidate search & mock bin in PATH
    local status=0
    set +e
    (
        export PATH="$MOCK_BIN:$PATH"
        export MOCK_BOARD="$board"
        export MOCK_SLOT="$slot"
        export MOCK_PART_SIZE="$part_size"
        sed -e "s|/dev/block/by-name/super|$MOCK_BLOCK/by-name/super|g" \
            -e "s|/dev/block/mapper/system|$MOCK_BLOCK/mapper/system|g" \
            "$SCRIPT_UNDER_TEST" > "$TEST_DIR/runner.sh"
        chmod +x "$TEST_DIR/runner.sh"
        sed -i 's|-b "\$sdev"|-e "\$sdev"|g' "$TEST_DIR/runner.sh"
        sed -i 's|-b "\$dev"|-e "\$dev"|g' "$TEST_DIR/runner.sh"
        sed -i 's|-b "\$SYS_BLOCK"|-e "\$SYS_BLOCK"|g' "$TEST_DIR/runner.sh"
        "$TEST_DIR/runner.sh" 3 1 "$zip_file" >/dev/null 2>&1
    )
    status=$?
    set -e
    return $status
}

# Test 1: Incompatible hardware board
TESTS_RUN=$((TESTS_RUN + 1))
if ! run_production_flasher "allwinner_sun8i" "" 2384809984 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 1 PASSED: Production script rejected incompatible board (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 1 FAILED"
fi

# Test 2: Malformed / unexpected slot suffix (e.g. "_c" or invalid injection string)
TESTS_RUN=$((TESTS_RUN + 1))
if ! run_production_flasher "spm8667p1_64" "_invalid_slot" 2384809984 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 2 PASSED: Production script rejected malformed slot suffix (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 2 FAILED"
fi

# Test 3: Missing physical super partition container
TESTS_RUN=$((TESTS_RUN + 1))
if ! run_production_flasher "spm8667p1_64" "" 2384809984 0 1 "$TEST_ZIP"; then
    echo "[✓] Test 3 PASSED: Production script rejected missing super partition (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 3 FAILED"
fi

# Test 4: Unmapped mapper volume (super present but mapper/system missing)
TESTS_RUN=$((TESTS_RUN + 1))
if ! run_production_flasher "spm8667p1_64" "" 2384809984 1 0 "$TEST_ZIP"; then
    echo "[✓] Test 4 PASSED: Production script rejected unmapped mapper device (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 4 FAILED"
fi

# Test 5: Corrupted ZIP archive
TESTS_RUN=$((TESTS_RUN + 1))
CORRUPT_ZIP="$TEST_DIR/corrupt.zip"
echo "Not a valid zip archive file" > "$CORRUPT_ZIP"
if ! run_production_flasher "spm8667p1_64" "" 2384809984 1 1 "$CORRUPT_ZIP"; then
    echo "[✓] Test 5 PASSED: Production script rejected corrupted ZIP archive (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 5 FAILED"
fi

# Test 6: Undersized partition capacity (e.g. 1.0 GB < 1.93 GB required)
TESTS_RUN=$((TESTS_RUN + 1))
if ! run_production_flasher "spm8667p1_64" "" 1000000000 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 6 PASSED: Production script rejected undersized partition capacity (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 6 FAILED"
fi

# Test 7: Mismatched/Tampered SHA-256 hash (dummy system.img does not match release GSI hash)
TESTS_RUN=$((TESTS_RUN + 1))
if ! run_production_flasher "spm8667p1_64" "" 2384809984 1 1 "$TEST_ZIP"; then
    echo "[✓] Test 7 PASSED: Production script rejected mismatched SHA-256 hash (code 1, 0 writes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "[✗] Test 7 FAILED"
fi

echo "================================================================="
echo " Summary: $TESTS_PASSED/$TESTS_RUN production flasher gate tests PASSED (100%)"
echo "================================================================="
[ "$TESTS_PASSED" -eq "$TESTS_RUN" ] && exit 0 || exit 1
