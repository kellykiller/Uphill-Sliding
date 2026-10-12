#!/usr/bin/env python3
# HISTORICAL/BETA or completed one-off repair only; not for current releases.
"""Install a local LinuxServer prototype ZIP; retain existing SML/other mods."""
import argparse
import datetime
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import zipfile


VERSION = "1.1.0-beta.1"


def validate_archive(archive):
    names = set(archive.namelist())
    for entry in archive.infolist():
        path = PurePosixPath(entry.filename.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts or ":" in entry.filename:
            raise ValueError("Unsafe archive path: " + entry.filename)
        if (entry.external_attr >> 16) & 0o170000 == 0o120000:
            raise ValueError("Archive contains a symbolic link: " + entry.filename)
    descriptor = json.loads(archive.read("UphillSliding.uplugin"))
    if (descriptor.get("SemVersion") != VERSION or
            descriptor.get("VersionName") != VERSION or
            descriptor.get("GameFeature") is not True or
            descriptor.get("RequiredOnRemote") is not True):
        raise ValueError("Expected GameFeature / RequiredOnRemote beta " + VERSION)
    manifests = [n for n in names if n.startswith("Binaries/Linux/FactoryServer-")
                 and n.endswith(".modules")]
    if not manifests:
        raise ValueError("Linux FactoryServer module manifest is missing")
    for name in manifests:
        manifest = json.loads(archive.read(name))
        module = manifest.get("Modules", {}).get("SlideMomentum", "")
        if manifest.get("BuildId") != "SML" or not module.endswith(".so"):
            raise ValueError("Invalid Linux module manifest: " + name)
        if PurePosixPath(module).name != module or "\\" in module:
            raise ValueError("Invalid module filename")
        binary = str(PurePosixPath(name).parent / module)
        with archive.open(binary) as stream:
            header = stream.read(20)
        if (len(header) < 20 or header[:4] != b"\x7fELF" or header[4] != 2
                or header[5] != 1 or int.from_bytes(header[18:20], "little") != 62):
            raise ValueError("Expected an ELF64 x86_64 Linux module: " + binary)
    for extension in (".pak", ".utoc", ".ucas"):
        if not any(n.startswith("Content/") and n.endswith(extension)
                   and archive.getinfo(n).file_size > 0 for n in names):
            raise ValueError("Missing cooked content: " + extension)


def install(archive_path, game_root, container):
    game_root = game_root.resolve()
    if not (game_root / "FactoryServer.sh").is_file():
        raise ValueError("FactoryServer.sh not found under " + str(game_root))
    mods = game_root / "FactoryGame/Mods"
    sml_path = mods / "SML/SML.uplugin"
    sml = json.loads(sml_path.read_text(encoding="utf-8-sig"))
    version = sml.get("SemVersion", sml.get("VersionName", ""))
    parts = version.split(".")
    if len(parts) < 2 or parts[0] != "3" or int(parts[1]) < 12:
        raise ValueError("SML 3.12.x or compatible later 3.x is required")
    for legacy in (mods / "UphillSliding", mods / "GameFeatures/SlideMomentum"):
        if legacy.exists():
            raise ValueError("Conflicting legacy mod folder: " + str(legacy))
    subprocess.run(["docker", "inspect", "--format", "{{.State.Running}}", container],
                   check=True, capture_output=True, text=True)
    backup_root = game_root.parent / "uphill-sliding-backups"
    backup_root.mkdir(exist_ok=True)
    # Stage outside FactoryGame/Mods so a running server cannot discover it early.
    stage = Path(tempfile.mkdtemp(prefix="staging-", dir=backup_root))
    target = mods / "GameFeatures/UphillSliding"
    backup = None
    installed = False
    try:
        with zipfile.ZipFile(archive_path) as archive:
            validate_archive(archive)
            archive.extractall(stage)
        # ZIP extraction may not preserve Unix permissions. All native libraries
        # and content only need to be readable, and directories traversable.
        for path in stage.rglob("*"):
            path.chmod(0o755 if path.is_dir() else 0o644)
        stage.chmod(0o755)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.is_symlink():
            raise ValueError("Target is a symbolic link; installation stopped")
        print("Archive validated. Stopping " + container, flush=True)
        subprocess.run(["docker", "stop", "--time", "120", container], check=True)
        if target.exists():
            stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
            backup = backup_root / ("UphillSliding-" + stamp)
            target.rename(backup)
            print("Previous plugin backup: " + str(backup), flush=True)
        try:
            stage.rename(target)
        except Exception:
            if backup is not None and not target.exists():
                backup.rename(target)
            raise
        installed = True
        print("Installed " + VERSION + ": " + str(target), flush=True)
        subprocess.run(["docker", "start", container], check=True)
        print("Server started. Check the startup log before joining.", flush=True)
        print("Other mods and the existing SML installation were retained.", flush=True)
    finally:
        if not installed and stage.exists():
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("game_root", type=Path)
    parser.add_argument("--container", default="satisfactory-server")
    args = parser.parse_args()
    try:
        install(args.archive.expanduser(), args.game_root.expanduser(), args.container)
    except Exception as error:
        parser.exit(1, "Installation failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
