#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "hldm_trap.sma"
CONFIG = ROOT / "configs" / "plugins" / "hldm_trap.cfg"

required_files = [
    SOURCE,
    CONFIG,
    ROOT / "README.md",
    ROOT / "CHANGELOG.md",
    ROOT / "docs" / "INSTALL_RU.md",
    ROOT / "docs" / "ARCHITECTURE.md",
    ROOT / "docs" / "TEST_PLAN.md",
    ROOT / "deploy" / "install_windows.ps1",
    ROOT / "deploy" / "uninstall_windows.ps1",
    ROOT / ".github" / "workflows" / "compile.yml",
]

errors: list[str] = []
for path in required_files:
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")

source_files = sorted((ROOT / "src").glob("*.sma")) if (ROOT / "src").is_dir() else []
if not source_files:
    errors.append("no Pawn sources found in src/")

for source_path in source_files:
    source = source_path.read_text(encoding="utf-8")
    lowered = source.lower()

    forbidden_calls = (
        "client_cmd(",
        "engclient_cmd(",
        "amxclient_cmd(",
        "client_execute(",
        "server_cmd(\"kick",
        "server_cmd(\"ban",
    )
    for call in forbidden_calls:
        if call in lowered:
            errors.append(f"{source_path.relative_to(ROOT)}: forbidden call found: {call}")

if SOURCE.is_file():
    source = SOURCE.read_text(encoding="utf-8")

    for command in (
        "amx_trap",
        "amx_untrap",
        "amx_trap_id",
        "amx_untrap_id",
        "amx_trap_list",
        "amx_trap_start",
        "amx_trap_stop",
    ):
        if command not in source:
            errors.append(f"missing admin command: {command}")

    required_guards = (
        "!g_trapped[id]",
        "hldm_trap_protect_admins",
        "hldm_trap_allow_self",
        "hldm_trap_allow_bots",
        'AutoExecConfig(true, "hldm_trap")',
    )
    for guard in required_guards:
        if guard not in source:
            errors.append(f"missing safety/ordinary-player contract: {guard}")

    registered_cvars = set(re.findall(r'register_cvar\("([a-z0-9_]+)"', source))
else:
    registered_cvars = set()

if CONFIG.is_file():
    config = CONFIG.read_text(encoding="utf-8")
    configured_cvars = set(re.findall(r'^\s*(hldm_trap_[a-z0-9_]+)\s+', config, re.MULTILINE))

    missing_in_config = sorted(registered_cvars - configured_cvars)
    unknown_in_config = sorted(configured_cvars - registered_cvars)

    if missing_in_config:
        errors.append("cvars missing in config: " + ", ".join(missing_in_config))
    if unknown_in_config:
        errors.append("config contains unregistered cvars: " + ", ".join(unknown_in_config))

old_config = ROOT / "configs" / "hldm_trap.cfg"
if old_config.exists():
    errors.append("obsolete config path exists; AMXX AutoExecConfig loads configs/plugins/hldm_trap.cfg")

if errors:
    print("CONTRACT CHECK FAILED")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print(f"Contract check passed: {len(source_files)} source file(s), {len(registered_cvars)} cvar(s).")
