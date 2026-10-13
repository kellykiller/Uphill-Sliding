#!/usr/bin/env python3
"""Verify build-input SHA-256 pins against their immutable Git revision."""
import hashlib
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent


def git_bytes(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def check():
    script_path = ROOT / "Tools/Prepare-Release.ps1"
    raw = script_path.read_bytes()
    text = raw.decode("ascii")
    if b"\n" in raw.replace(b"\r\n", b""):
        raise ValueError("Prepare-Release.ps1 must have CRLF line endings")
    for line in text.splitlines():
        if line.strip() == "'@" and line != "'@":
            raise ValueError("Here-string terminator must start in column zero")

    block = text.split("# RELEASE_PINS_BEGIN", 1)[1].split("# RELEASE_PINS_END", 1)[0]
    commit_match = re.search(r"\$sourceCommit = '([0-9a-f]{40})'", block)
    if commit_match is None:
        raise ValueError("Missing immutable release source commit")
    commit = commit_match.group(1)
    entries = re.findall(r"Path = '([^']+)'; Hash = '([0-9a-f]{64})'", block)
    if not entries or len(entries) != block.count("[pscustomobject]"):
        raise ValueError("Empty or malformed release payload")
    paths = [path for path, _ in entries]
    if len(paths) != len(set(paths)):
        raise ValueError("Duplicate release pin path")
    for path in paths:
        parsed = PurePosixPath(path)
        if (parsed.is_absolute() or ".." in parsed.parts or "\\" in path or
                ":" in path or str(parsed) != path or not
                (path.startswith(("Source/", "Config/")) or path == "UphillSliding.uplugin")):
            raise ValueError("Not a safe build-input path: " + path)

    expected = set(git_bytes("ls-tree", "-r", "--name-only", "HEAD", "--",
                             "Source", "Config", "UphillSliding.uplugin").decode().splitlines())
    if set(paths) != expected:
        raise ValueError("Pins must cover exactly the tracked Source/Config/plugin build inputs")
    for path, expected_hash in entries:
        pinned = git_bytes("show", commit + ":" + path)
        if hashlib.sha256(pinned).hexdigest() != expected_hash:
            raise ValueError("SHA-256 mismatch at pinned commit: " + path)
        if pinned != git_bytes("show", "HEAD:" + path):
            raise ValueError("Current build input differs from pinned source: " + path)
    print(f"PASS {len(entries)} build-input SHA-256 pins at {commit}; current build inputs match")


if __name__ == "__main__":
    try:
        check()
    except (ValueError, IndexError, UnicodeError, subprocess.CalledProcessError) as error:
        sys.exit("Release pin check failed: " + str(error))
