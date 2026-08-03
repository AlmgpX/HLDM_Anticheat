#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "hldm_trap.sma"
CONFIG = ROOT / "configs" / "hldm_trap.cfg"

required_files = [
    SOURCE,
    CONFIG,
    ROOT / "README.md",
    ROOT / "docs" / "INSTALL_RU.md",
    ROOT / ".github" / "workflows" / "compile.yml",
]

errors: list[str] = []
for path in required_files:
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")

if SOURCE.is_file():
    source = SOURCE.read_text(encoding="utf-8")
    lowered = source.lower()

    forbidden_calls = (
        "client_cmd(",
        "engclient_cmd(",
        "amxclient_cmd(",
        "server_cmd(\"kick",
    )
    for call in forbidden_calls:
        if call in lowered:
            errors.append(f"forbidden client-affecting call found: {call}")

    for command in ("amx_trap", "amx_untrap", "amx_trap_list"):
        if command not in source:
            errors.append(f"missing admin command: {command}")

    if "!g_trapped[id]" not in source:
        errors.append("missing ordinary-player fast path in command hook")

    registered_cvars = set(re.findall(r'register_cvar\("([a-z0-9_]+)"', source))
else:
    registered_cvars = set()

if CONFIG.is_file():
    config = CONFIG.read_text(encoding="utf-8")
    configured_cvars = set(re.findall(r'^\s*(hldm_trap_[a-z0-9_]+)\s+', config, re.MULTILINE))
    missing_in_config = sorted(registered_cvars - configured_cvars)
    if missing_in_config:
        errors.append("cvars missing in config: " + ", ".join(missing_in_config))

if errors:
    print("CONTRACT CHECK FAILED")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("Contract check passed.")
