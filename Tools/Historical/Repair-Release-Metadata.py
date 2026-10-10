#!/usr/bin/env python3
# HISTORICAL/BETA or completed one-off repair only; not for current releases.
"""Repair only the three 1.1.0 descriptor Version fields in the known release ZIP."""
import argparse
import copy
import hashlib
import json
import re
import zipfile
from pathlib import Path, PurePosixPath

ORIGINAL_SHA256 = "ca3d3fd80aef764485ef6080c122b787aa865279adcafd8c5678cd3b8ea2b466"
DESCRIPTORS = {p + "/UphillSliding.uplugin" for p in ("Windows", "WindowsServer", "LinuxServer")}

def repair(source: Path, destination: Path):
    if source.resolve() == destination.resolve() or destination.exists():
        raise ValueError("Use a new output path; the input is never overwritten.")
    if hashlib.sha256(source.read_bytes()).hexdigest() != ORIGINAL_SHA256:
        raise ValueError("Unexpected original archive checksum.")
    with zipfile.ZipFile(source) as old:
        names = old.namelist()
        if len(names) != len(set(names)) or not DESCRIPTORS.issubset(names) or old.testzip() is not None:
            raise ValueError("Invalid original ZIP.")
        replacements = {}
        for name in names:
            path = PurePosixPath(name.replace("\\", "/"))
            if path.is_absolute() or ".." in path.parts or ":" in name:
                raise ValueError("Unsafe ZIP path.")
        for name in DESCRIPTORS:
            data = old.read(name)
            descriptor = json.loads(data)
            if descriptor["SemVersion"] != "1.1.0" or descriptor["VersionName"] != "1.1.0" or descriptor["Version"] != 2:
                raise ValueError("Unexpected original descriptor.")
            new, count = re.subn(rb'("Version"\s*:\s*)2(\s*,)', rb'\g<1>1\2', data)
            if count != 1:
                raise ValueError("Version field must occur exactly once.")
            expected = dict(descriptor)
            expected["Version"] = 1
            if json.loads(new) != expected:
                raise ValueError("Unexpected metadata change.")
            replacements[name] = new
        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            with zipfile.ZipFile(destination, "w") as new:
                new.comment = old.comment
                for entry in old.infolist():
                    data = replacements[entry.filename] if entry.filename in replacements else old.read(entry.filename)
                    new.writestr(copy.copy(entry), data)
            with zipfile.ZipFile(destination) as new:
                if new.namelist() != names or new.testzip() is not None:
                    raise ValueError("Invalid repaired ZIP.")
                for name in names:
                    expected = replacements[name] if name in replacements else old.read(name)
                    if new.read(name) != expected:
                        raise ValueError("Unexpected entry change: " + name)
                for name in DESCRIPTORS:
                    d = json.loads(new.read(name))
                    if d["Version"] != int(d["SemVersion"].split(".")[0]):
                        raise ValueError("Version must match SemVersion major.")
        except Exception:
            destination.unlink(missing_ok=True)
            raise
    print("Repaired metadata only; all native binaries and cooked content are byte-identical.")
    print("SHA256:", hashlib.sha256(destination.read_bytes()).hexdigest())
    print("SIZE:", destination.stat().st_size)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    repair(args.source, args.destination)
