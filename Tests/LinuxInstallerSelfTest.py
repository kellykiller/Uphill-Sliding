#!/usr/bin/env python3
"""Synthetic ZIP/filesystem/lifecycle tests; no Docker, Engine or game is run."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import struct
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile


spec = importlib.util.spec_from_file_location(
    "linux_release_installer", Path(__file__).resolve().parent.parent /
    "Tools/Install-LinuxServer-Release.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


def synthetic_elf():
    header = bytearray(64)
    header[:7] = b"\x7fELF\x02\x01\x01"
    struct.pack_into("<HHI", header, 16, 3, 62, 1)
    struct.pack_into("<H", header, 52, 64)
    return bytes(header)


def synthetic_entries():
    descriptor = {"Version": 1, "VersionName": "1.1.1", "SemVersion": "1.1.1",
                  "GameFeature": True, "RequiredOnRemote": True,
                  "IsBetaVersion": False, "IsExperimentalVersion": False,
                  "Modules": [{"Name": "UphillSliding"}]}
    manifest = {"BuildId": "SML", "Modules": {"UphillSliding": "libUphillSliding.so"}}
    entries = {"UphillSliding.uplugin": json.dumps(descriptor),
               installer.MANIFEST: json.dumps(manifest),
               "Binaries/Linux/libUphillSliding.so": synthetic_elf()}
    for extension in ("pak", "utoc", "ucas"):
        entries[f"Content/Paks/LinuxServer/UphillSlidingFactoryGame-LinuxServer.{extension}"] = b"synthetic"
    return entries


class FakeController:
    def __init__(self, running=True, fail_stop=False, fail_start=False):
        self.running = running
        self.fail_stop = fail_stop
        self.fail_start = fail_start
        self.calls = []

    def is_running(self):
        self.calls.append("inspect")
        return self.running

    def stop(self):
        self.calls.append("stop")
        if self.fail_stop:
            raise RuntimeError("synthetic stop failure")
        self.running = False

    def start(self):
        self.calls.append("start")
        if self.fail_start:
            raise RuntimeError("synthetic start failure")
        self.running = True


class LinuxInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.game = self.root / "gamefiles"
        self.sml = self.game / "FactoryGame/Mods/SML"
        self.target = self.game / "FactoryGame/Mods/GameFeatures/UphillSliding"
        self.sml.mkdir(parents=True)
        self.target.mkdir(parents=True)
        (self.game / "FactoryServer.sh").write_text("synthetic; never executed")
        (self.target / "previous.txt").write_text("previous plugin")
        (self.sml / "SML.uplugin").write_text(json.dumps({"SemVersion": "3.12.0"}))
        (self.sml / "Binaries/Linux").mkdir(parents=True)
        (self.sml / installer.MANIFEST).write_text(json.dumps(
            {"BuildId": "SML", "Modules": {"SML": "libSML.so"}}))
        (self.sml / "Binaries/Linux/libSML.so").write_bytes(synthetic_elf())
        self.other = self.game / "FactoryGame/Mods/OtherMod"
        self.other.mkdir()
        (self.other / "keep.txt").write_text("retain")
        self.archive = self.root / "UphillSliding-LinuxServer.zip"
        self.write_zip(synthetic_entries())

    def write_zip(self, entries):
        items = entries.items() if isinstance(entries, dict) else entries
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.archive, "w") as archive:
                for name, content in items:
                    archive.writestr(name, content)

    def validate(self):
        with zipfile.ZipFile(self.archive) as archive:
            return installer.validate_archive(archive)

    def install(self, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            return installer.install(self.archive, self.game, **kwargs)

    def test_valid_platform_archive(self):
        self.assertEqual(self.validate()["SemVersion"], "1.1.1")

    def test_unsafe_paths(self):
        for name in ("../escape", "/absolute", "C:/escape", "a\\escape",
                     "a/../escape", "a//escape", "a/./escape", "a/\x00escape"):
            with self.subTest(name=name):
                entries = synthetic_entries()
                # zipfile's writer truncates NUL names. Insert the NUL into the
                # serialized local/central filename so this is a real bad ZIP.
                entries[name.replace("\x00", "_")] = b"unsafe"
                self.write_zip(entries)
                if "\x00" in name:
                    self.archive.write_bytes(self.archive.read_bytes().replace(
                        name.replace("\x00", "_").encode(), name.encode()))
                with self.assertRaises(ValueError):
                    self.validate()

    def test_duplicate_paths(self):
        entries = list(synthetic_entries().items())
        self.write_zip(entries + [entries[0]])
        with self.assertRaises(ValueError):
            self.validate()

    def test_symbolic_link_and_special_file(self):
        for mode in (stat.S_IFLNK, stat.S_IFIFO):
            with self.subTest(mode=mode):
                info = zipfile.ZipInfo("unsafe")
                info.create_system = 3
                info.external_attr = (mode | 0o777) << 16
                self.write_zip(list(synthetic_entries().items()) + [(info, b"../escape")])
                with self.assertRaises(ValueError):
                    self.validate()

    def test_file_directory_conflict(self):
        entries = synthetic_entries()
        entries.update({"extra": b"file", "extra/child": b"file"})
        self.write_zip(entries)
        with self.assertRaises(ValueError):
            self.validate()

    def test_wrong_version_or_module_or_policy(self):
        for field, value in (("SemVersion", "1.1.0"), ("Version", True),
                             ("Modules", [{"Name": "SlideMomentum"}]),
                             ("RequiredOnRemote", False), ("IsBetaVersion", True)):
            with self.subTest(field=field):
                entries = synthetic_entries()
                descriptor = json.loads(entries["UphillSliding.uplugin"])
                descriptor[field] = value
                entries["UphillSliding.uplugin"] = json.dumps(descriptor)
                self.write_zip(entries)
                with self.assertRaises(ValueError):
                    self.validate()

    def test_wrong_manifest_or_binary_path(self):
        for manifest in ({"BuildId": "wrong", "Modules": {"UphillSliding": "a.so"}},
                         {"BuildId": "SML", "Modules": {"SlideMomentum": "a.so"}},
                         {"BuildId": "SML", "Modules": {"UphillSliding": "../a.so"}}):
            with self.subTest(manifest=manifest):
                entries = synthetic_entries()
                entries[installer.MANIFEST] = json.dumps(manifest)
                self.write_zip(entries)
                with self.assertRaises(ValueError):
                    self.validate()

    def test_wrong_elf(self):
        variants = [b"MZ" + bytes(62), synthetic_elf()[:20]]
        arm = bytearray(synthetic_elf())
        struct.pack_into("<H", arm, 18, 183)
        variants.append(bytes(arm))
        for binary in variants:
            with self.subTest(binary=binary[:20]):
                entries = synthetic_entries()
                entries["Binaries/Linux/libUphillSliding.so"] = binary
                self.write_zip(entries)
                with self.assertRaises(ValueError):
                    self.validate()

    def test_missing_binary_or_cooked_content(self):
        required = ["Binaries/Linux/libUphillSliding.so"] + [
            f"Content/Paks/LinuxServer/UphillSlidingFactoryGame-LinuxServer.{ext}"
            for ext in ("pak", "utoc", "ucas")]
        for name in required:
            with self.subTest(name=name):
                entries = synthetic_entries()
                del entries[name]
                self.write_zip(entries)
                with self.assertRaises(ValueError):
                    self.validate()

    def test_empty_cooked_content(self):
        entries = synthetic_entries()
        entries["Content/Paks/LinuxServer/UphillSlidingFactoryGame-LinuxServer.pak"] = b""
        self.write_zip(entries)
        with self.assertRaises(ValueError):
            self.validate()

    def test_install_backs_up_only_plugin_and_restores_running_state(self):
        controller = FakeController()
        previous_sml = (self.sml / "SML.uplugin").read_bytes()
        backup = self.install(controller=controller)
        self.assertEqual((backup / "PreviousPlugin/previous.txt").read_text(), "previous plugin")
        self.assertTrue((self.target / "UphillSliding.uplugin").is_file())
        self.assertFalse((self.target / "previous.txt").exists())
        self.assertEqual((self.sml / "SML.uplugin").read_bytes(), previous_sml)
        self.assertEqual((self.other / "keep.txt").read_text(), "retain")
        self.assertEqual(controller.calls, ["inspect", "stop", "inspect", "start"])
        self.assertTrue(controller.running)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o755)
        self.assertEqual(stat.S_IMODE((self.target / "UphillSliding.uplugin").stat().st_mode), 0o644)

    def test_stopped_container_stays_stopped(self):
        controller = FakeController(running=False)
        self.install(controller=controller)
        self.assertEqual(controller.calls, ["inspect"])
        self.assertFalse(controller.running)

    def test_manual_server_requires_acknowledgement(self):
        with self.assertRaises(ValueError):
            self.install()
        self.assertTrue((self.target / "previous.txt").is_file())
        self.install(server_stopped=True)
        self.assertTrue((self.target / "UphillSliding.uplugin").is_file())

    def test_failed_replace_restores_previous_plugin_and_running_state(self):
        controller = FakeController()
        original_move = installer.move_directory

        def fail_stage(source, destination):
            if source.name.startswith("staging-"):
                raise OSError("synthetic move failure")
            original_move(source, destination)

        with patch.object(installer, "move_directory", side_effect=fail_stage):
            with self.assertRaises(OSError):
                self.install(controller=controller)
        self.assertEqual((self.target / "previous.txt").read_text(), "previous plugin")
        self.assertTrue(controller.running)
        self.assertEqual(list(self.root.rglob("staging-*")), [])

    def test_invalid_archive_never_stops_or_replaces_server(self):
        entries = synthetic_entries()
        del entries[installer.MANIFEST]
        self.write_zip(entries)
        controller = FakeController()
        with self.assertRaises(ValueError):
            self.install(controller=controller)
        self.assertEqual(controller.calls, [])
        self.assertTrue((self.target / "previous.txt").is_file())

    def test_missing_or_incompatible_sml(self):
        controller = FakeController()
        (self.sml / "SML.uplugin").write_text(json.dumps({"SemVersion": "3.11.0"}))
        with self.assertRaises(ValueError):
            self.install(controller=controller)
        (self.sml / "SML.uplugin").unlink()
        with self.assertRaises(FileNotFoundError):
            self.install(controller=controller)
        self.assertEqual(controller.calls, [])

    def test_symlink_target_is_rejected(self):
        destination = self.root / "outside"
        self.target.rename(destination)
        self.target.symlink_to(destination, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.install(controller=FakeController())
        self.assertEqual((destination / "previous.txt").read_text(), "previous plugin")

    def test_stop_failure_does_not_replace_plugin(self):
        controller = FakeController(fail_stop=True)
        with self.assertRaises(RuntimeError):
            self.install(controller=controller)
        self.assertTrue((self.target / "previous.txt").is_file())
        self.assertEqual(list(self.root.rglob("staging-*")), [])

    def test_start_failure_keeps_valid_install_and_backup(self):
        controller = FakeController(fail_start=True)
        with self.assertRaises(RuntimeError):
            self.install(controller=controller)
        self.assertTrue((self.target / "UphillSliding.uplugin").is_file())
        self.assertEqual(len(list(self.root.rglob("PreviousPlugin/previous.txt"))), 1)


if __name__ == "__main__":
    unittest.main(verbosity=1)
