"""Artifact-gate regressions using constructed ELF/ZIP boundary cases."""
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
import warnings
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "android_native", Path(__file__).resolve().parents[1] / "scripts/check_android_native.py")
native = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(native)


def elf(*, alignment=16384, machine=183, kind=1, offset=0, address=0, size=128, memory_size=128):
    header = struct.pack("<16sHHIQQQIHHHHHH", b"\x7fELF\x02\x01\x01" + b"\0" * 9,
                         3, machine, 1, 0, 64, 0, 0, 64, 56, 1, 0, 0, 0)
    segment = struct.pack("<IIQQQQQQ", kind, 5, offset, address, 0, size, memory_size, alignment)
    return header + segment + b"\0" * 8


class NativeArtifactTests(unittest.TestCase):
    def inspect(self, data, *, aligned=True, compressed=False, abi="arm64-v8a"):
        with tempfile.TemporaryDirectory(prefix="nightshift-native-test-") as directory:
            apk = Path(directory) / "synthetic.apk"
            name = f"lib/{abi}/libsynthetic.so"
            item = zipfile.ZipInfo(name)
            item.compress_type = zipfile.ZIP_DEFLATED if compressed else zipfile.ZIP_STORED
            if aligned:
                padding = 16384 - 30 - len(name.encode())
                item.extra = struct.pack("<HH", 0xD935, padding - 4) + b"\0" * (padding - 4)
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr(item, data)
            return native.inspect_apk(apk)

    def test_aligned_arm64_and_x86_64_are_inspected_without_runtime_claim(self):
        for abi, machine in [("arm64-v8a", 183), ("x86_64", 62)]:
            result = self.inspect(elf(machine=machine), abi=abi)
            self.assertTrue(result["allElfAligned"])
            self.assertTrue(result["allStoredZipAligned"])
            self.assertFalse(result["runtime16kbTested"])
            self.assertEqual(len(result["sha256"]), 64)

    def test_four_kib_elf_is_rejected_despite_aligned_zip(self):
        result = self.inspect(elf(alignment=4096))
        self.assertFalse(result["allElfAligned"])
        self.assertTrue(result["allStoredZipAligned"])

    def test_stored_zip_misalignment_is_rejected_despite_aligned_elf(self):
        result = self.inspect(elf(), aligned=False)
        self.assertTrue(result["allElfAligned"])
        self.assertFalse(result["allStoredZipAligned"])

    def test_compressed_library_still_requires_elf_alignment(self):
        for alignment in [4096, 16384]:
            result = self.inspect(elf(alignment=alignment), aligned=False, compressed=True)
            self.assertIsNone(result["libraries"][0]["zip16kbAligned"])
            self.assertEqual(result["allElfAligned"], alignment == 16384)

    def test_noncongruent_or_non_power_of_two_load_alignment_is_rejected(self):
        for data in [elf(address=4096), elf(alignment=24576)]:
            self.assertFalse(self.inspect(data)["allElfAligned"])

    def test_wrong_architecture_and_missing_load_segments_are_invalid(self):
        for data in [elf(machine=62), elf(kind=2)]:
            with self.assertRaises(ValueError):
                self.inspect(data)

    def test_truncated_or_unbounded_program_header_is_invalid(self):
        huge = bytearray(elf())
        struct.pack_into("<Q", huge, 32, 2**63)
        for data in [b"\x7fELF", elf()[:90], huge]:
            with self.assertRaises(ValueError):
                native.elf_alignment(io.BytesIO(data), len(data), 183)

    def test_file_and_memory_segment_bounds_are_validated(self):
        for data in [elf(size=129), elf(memory_size=127), elf(offset=16384)]:
            with self.assertRaises(ValueError):
                self.inspect(data)

    def test_empty_or_duplicate_native_apk_is_invalid(self):
        with tempfile.TemporaryDirectory(prefix="nightshift-native-test-") as directory:
            apk = Path(directory) / "synthetic.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("assets/example.txt", "empty")
            with self.assertRaisesRegex(ValueError, "no supported"):
                native.inspect_apk(apk)
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(apk, "w") as archive:
                    archive.writestr("lib/arm64-v8a/libsynthetic.so", elf())
                    archive.writestr("lib/arm64-v8a/libsynthetic.so", elf())
            with self.assertRaisesRegex(ValueError, "duplicate"):
                native.inspect_apk(apk)


if __name__ == "__main__":
    unittest.main()
