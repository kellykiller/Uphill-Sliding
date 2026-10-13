#!/usr/bin/env python3
"""Install a local 1.1.1 LinuxServer ZIP; preserve existing SML and other mods.

This installer has synthetic self-test coverage, not a real-server validation.
Use --container for Docker lifecycle management or --server-stopped after manually
stopping a native server. A stopped container remains stopped after installation.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import subprocess
import tempfile
import zipfile


VERSION = "1.1.1"
MODULE = "UphillSliding"
MANIFEST = "Binaries/Linux/FactoryServer-Linux-Shipping.modules"


def read_json(archive, name):
    try:
        return json.loads(archive.read(name).decode("utf-8-sig"))
    except (KeyError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Missing or invalid JSON entry: " + name) from error


def validate_elf(header, name):
    if (len(header) < 64 or header[:7] != b"\x7fELF\x02\x01\x01" or
            struct.unpack_from("<HHI", header, 16) != (3, 62, 1) or
            struct.unpack_from("<H", header, 52)[0] != 64):
        raise ValueError("Expected an ELF64 little-endian x86_64 shared library: " + name)


def validate_archive(archive):
    paths = set()
    files = set()
    for entry in archive.infolist():
        name = entry.filename
        path = PurePosixPath(name)
        normalized = str(path)
        file_type = stat.S_IFMT(entry.external_attr >> 16)
        if (name != entry.orig_filename or not name or path.is_absolute() or
                ".." in path.parts or "\\" in name or ":" in name or
                any(ord(char) < 32 or ord(char) == 127 for char in name) or
                normalized != name.rstrip("/") or name.endswith("//") or
                normalized in paths or file_type not in (0, stat.S_IFREG, stat.S_IFDIR)):
            raise ValueError("Unsafe or duplicate archive path: " + name)
        paths.add(normalized)
        if not entry.is_dir():
            files.add(normalized)
    if any(str(parent) in files for name in paths for parent in PurePosixPath(name).parents):
        raise ValueError("Archive contains a file/directory path conflict")
    bad_crc = archive.testzip()
    if bad_crc is not None:
        raise ValueError("ZIP integrity failure: " + bad_crc)

    descriptor = read_json(archive, MODULE + ".uplugin")
    if (not isinstance(descriptor, dict) or descriptor.get("SemVersion") != VERSION or
            descriptor.get("VersionName") != VERSION or
            type(descriptor.get("Version")) is not int or descriptor["Version"] != 1 or
            descriptor.get("GameFeature") is not True or
            descriptor.get("RequiredOnRemote") is not True or
            descriptor.get("IsBetaVersion") is not False or
            descriptor.get("IsExperimentalVersion") is not False or
            not isinstance(descriptor.get("Modules"), list) or
            len(descriptor["Modules"]) != 1 or
            not isinstance(descriptor["Modules"][0], dict) or
            descriptor["Modules"][0].get("Name") != MODULE):
        raise ValueError("Expected UphillSliding 1.1.1 release metadata and module")
    manifest = read_json(archive, MANIFEST)
    modules = manifest.get("Modules", {}) if isinstance(manifest, dict) else {}
    if (not isinstance(modules, dict) or set(modules) != {MODULE} or
            manifest.get("BuildId") != "SML"):
        raise ValueError("Invalid LinuxServer module manifest")
    binary_name = modules[MODULE]
    if (not isinstance(binary_name, str) or not binary_name.endswith(".so") or
            PurePosixPath(binary_name).name != binary_name or
            "\\" in binary_name or ":" in binary_name):
        raise ValueError("Invalid LinuxServer module filename")
    binary = str(PurePosixPath(MANIFEST).parent / binary_name)
    try:
        with archive.open(binary) as stream:
            validate_elf(stream.read(64), binary)
        for extension in ("pak", "utoc", "ucas"):
            name = f"Content/Paks/LinuxServer/{MODULE}FactoryGame-LinuxServer.{extension}"
            if archive.getinfo(name).file_size == 0:
                raise ValueError("Empty cooked content: " + name)
    except KeyError as error:
        raise ValueError("Required LinuxServer binary or cooked content is missing") from error
    return descriptor


def require_plain_directory(path):
    if path.is_symlink() or (path.exists() and not path.is_dir()):
        raise ValueError("Expected a plain directory or unused path: " + str(path))


def check_game_root(game_root):
    if not (game_root / "FactoryServer.sh").is_file():
        raise ValueError("FactoryServer.sh not found under " + str(game_root))
    mods = game_root / "FactoryGame/Mods"
    for relative in ("FactoryGame", "FactoryGame/Mods", "FactoryGame/Mods/SML",
                     "FactoryGame/Mods/GameFeatures", "FactoryGame/Mods/GameFeatures/UphillSliding"):
        require_plain_directory(game_root / relative)
    for legacy in (mods / MODULE, mods / "GameFeatures/SlideMomentum"):
        if legacy.exists() or legacy.is_symlink():
            raise ValueError("Conflicting legacy plugin directory: " + str(legacy))
    sml_root = mods / "SML"
    sml = json.loads((sml_root / "SML.uplugin").read_text(encoding="utf-8-sig"))
    version = sml.get("SemVersion", sml.get("VersionName", ""))
    match = re.fullmatch(r"3\.(\d+)\.(\d+)(?:\+[0-9A-Za-z.-]+)?", version)
    if match is None or int(match.group(1)) < 12:
        raise ValueError("Existing SML 3.12.x or a compatible later stable 3.x is required")
    manifest = json.loads((sml_root / MANIFEST).read_text(encoding="utf-8-sig"))
    name = manifest.get("Modules", {}).get("SML", "")
    if (manifest.get("BuildId") != "SML" or not name.endswith(".so") or
            PurePosixPath(name).name != name or "\\" in name or ":" in name):
        raise ValueError("Existing SML has no valid LinuxServer module manifest")
    with (sml_root / "Binaries/Linux" / name).open("rb") as stream:
        validate_elf(stream.read(64), name)
    return mods


class DockerController:
    def __init__(self, container):
        if not container or container.startswith("-"):
            raise ValueError("Invalid Docker container name")
        self.container = container

    def is_running(self):
        result = subprocess.run(["docker", "inspect", "--format", "{{.State.Running}}",
                                 self.container], check=True, capture_output=True, text=True)
        if result.stdout.strip() not in ("true", "false"):
            raise ValueError("Unexpected Docker container state")
        return result.stdout.strip() == "true"

    def stop(self):
        subprocess.run(["docker", "stop", "--timeout", "120", self.container], check=True)

    def start(self):
        subprocess.run(["docker", "start", self.container], check=True)


def move_directory(source, destination):
    source.rename(destination)


def install(archive_path, game_root, *, controller=None, server_stopped=False):
    archive_path = Path(archive_path).expanduser().resolve()
    game_root = Path(game_root).expanduser().resolve()
    if controller is None and not server_stopped:
        raise ValueError("Stop the native server and specify --server-stopped, or use --container")
    mods = check_game_root(game_root)
    with zipfile.ZipFile(archive_path) as archive:
        validate_archive(archive)
        was_running = controller.is_running() if controller is not None else False
        backup_base = game_root.parent / "uphill-sliding-backups"
        require_plain_directory(backup_base)
        backup_base.mkdir(exist_ok=True)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup_root = backup_base / stamp
        backup_root.mkdir()
        stage = Path(tempfile.mkdtemp(prefix="staging-", dir=backup_root))
        target = mods / "GameFeatures" / MODULE
        previous = backup_root / "PreviousPlugin"
        stopped_by_us = False
        try:
            archive.extractall(stage)
            stage.chmod(0o755)
            for path in stage.rglob("*"):
                path.chmod(0o755 if path.is_dir() else 0o644)
            if was_running:
                controller.stop()
                stopped_by_us = True
                if controller.is_running():
                    raise ValueError("Docker server did not stop; plugin was not replaced")
            target.parent.mkdir(parents=True, exist_ok=True)
            require_plain_directory(target)
            if target.exists():
                move_directory(target, previous)
            try:
                move_directory(stage, target)
            except Exception:
                if previous.exists() and not target.exists():
                    move_directory(previous, target)
                raise
            print(f"Installed {VERSION}: {target}", flush=True)
            print("Backup directory: " + str(backup_root), flush=True)
        finally:
            try:
                if stage.exists():
                    shutil.rmtree(stage)
            finally:
                if stopped_by_us:
                    controller.start()
    print("Existing SML and other mods retained. Install 1.1.1 on all clients/servers.")
    print("Archive SHA256: " + hashlib.sha256(archive_path.read_bytes()).hexdigest())
    print("Check the server startup log before joining; a stopped server/container stays stopped.")
    return backup_root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("game_root", type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--container", help="Docker container to stop/restart only if initially running")
    mode.add_argument("--server-stopped", action="store_true", help="Confirm native server is stopped")
    args = parser.parse_args()
    try:
        controller = DockerController(args.container) if args.container else None
        install(args.archive, args.game_root, controller=controller, server_stopped=args.server_stopped)
    except Exception as error:
        parser.exit(1, "Installation failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
