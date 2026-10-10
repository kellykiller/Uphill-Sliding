"""Validate descriptor fields without assuming a particular release version."""
import json
import re
from pathlib import Path

plugin = json.loads((Path(__file__).resolve().parents[1] / "UphillSliding.uplugin").read_text())
version = plugin["SemVersion"]
if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", version):
    raise SystemExit("Invalid SemVersion")
checks = {
    "VersionName must equal SemVersion": plugin["VersionName"] == version,
    "Version must equal the semantic major": type(plugin["Version"]) is int and plugin["Version"] == int(version.split(".")[0]),
    "Clients and servers require matching mods": plugin["RequiredOnRemote"] is True,
    "Expected native module": [module["Name"] for module in plugin["Modules"]] == ["UphillSliding"],
}
for message, passed in checks.items():
    if not passed:
        raise SystemExit(message)
print("PASS generic plugin metadata")
