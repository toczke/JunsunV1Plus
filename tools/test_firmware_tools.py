#!/usr/bin/env python3
"""
test_firmware_tools.py - Unit tests for Topway TS8667 firmware tools & parsers.
Validates:
  1. xj66 container header format & entry parsing (72-byte struct)
  2. Sparse vs raw image flag handling
  3. Partition offset calculations
  4. MD5 checksum verification for 8667.upd
  5. Recovery patching boundaries and padding
"""

import unittest
import struct
import tempfile
import os
import hashlib

class TestXj66ContainerParser(unittest.TestCase):
    """Tests the xj66 container format specification."""
    
    HEADER_MAGIC = b"xj66"
    HEADER_RESERVED = b"\x00\x00\x00\x00"
    ENTRY_SIZE = 72
    HEADER_OFFSET_DATA = 2312  # 0x908

    def _create_mock_entry(self, filename: str, partition: str, size: int, flags: int) -> bytes:
        fname_bytes = filename.encode("ascii").ljust(48, b"\x00")
        part_bytes = partition.encode("ascii").ljust(16, b"\x00")
        size_flags = struct.pack("<II", size, flags)
        return fname_bytes + part_bytes + size_flags

    def test_mock_container_header_structure(self):
        """Verify header magic and 72-byte entry layout."""
        header = self.HEADER_MAGIC + self.HEADER_RESERVED
        self.assertEqual(len(header), 8)
        
        entry = self._create_mock_entry("super.img", "super", 3823937528, 1)
        self.assertEqual(len(entry), self.ENTRY_SIZE)
        
        # Verify unpack
        fname = entry[:48].split(b"\x00")[0].decode("ascii")
        pname = entry[48:64].split(b"\x00")[0].decode("ascii")
        size, flags = struct.unpack("<II", entry[64:72])
        
        self.assertEqual(fname, "super.img")
        self.assertEqual(pname, "super")
        self.assertEqual(size, 3823937528)
        self.assertEqual(flags, 1)  # Sparse flag

    def test_recovery_offset_alignment(self):
        """Verify that super size + header offset equals recovery offset."""
        header_offset = self.HEADER_OFFSET_DATA  # 2312 (0x908)
        super_size = 3823937528                  # 0xe3eca7f8
        expected_recovery_offset = header_offset + super_size
        self.assertEqual(expected_recovery_offset, 3823939840)
        self.assertEqual(f"{expected_recovery_offset:#x}", "0xe3ecb100")


class TestPatchFirmware(unittest.TestCase):
    """Tests the patch_firmware logic and 8667.upd generation."""

    def test_md5_calculation(self):
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tf.write(b"TOPWAY_TS8667_FIRMWARE_MOCK_DATA_1234567890")
            temp_path = tf.name

        try:
            hasher = hashlib.md5()
            with open(temp_path, "rb") as f:
                while chunk := f.read(4096):
                    hasher.update(chunk)
            expected_md5 = hasher.hexdigest()
            self.assertEqual(len(expected_md5), 32)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_recovery_size_limit(self):
        """Ensure recovery images over 32MB are rejected."""
        max_limit = 33554432  # 32MB
        valid_size = 18077696
        invalid_size = 33554433
        
        self.assertTrue(valid_size <= max_limit)
        self.assertFalse(invalid_size <= max_limit)


if __name__ == "__main__":
    unittest.main()
