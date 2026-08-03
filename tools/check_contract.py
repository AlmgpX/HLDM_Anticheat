#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TRAP_SOURCE = ROOT / "src" / "hldm_trap.sma"
DETECTOR_SOURCE = ROOT / "src" / "hldm_detector.sma"
ADMIN_SOURCE = ROOT / "src" / "hldm_admin_tools.sma"
TRAP_CONFIG = ROOT / "configs" / "plugins" / "hldm_trap.cfg"
DETECTOR_CONFIG = ROOT / "configs" / "plugins" / "hldm_detector.cfg"
ADMIN_CONFIG = ROOT / "configs" / "plugins" / "hldm_admin_tools.cfg"

required_files = [
    TRAP_SOURCE,
    DETECTOR_SOURCE,
    ADMIN_SOURCE,
    TRAP_CONFIG,
    DETECTOR_CONFIG,
    ADMIN_CONFIG,
    ROOT / "README.md",
    ROOT / "CHANGELOG.md",
    ROOT / "docs" / "INSTALL_RU.md",
    ROOT / "docs" / "ARCHITECTURE.md",
    ROOT / "docs" / "TEST_PLAN.md",
    ROOT / "docs" / "DETECTOR_RU.md",
    ROOT / "docs" / "ADMIN_TOOLS_RU.md",
    ROOT / "deploy" / "setup_hldm_server_windows.ps1",
    ROOT / "deploy" / "install_fresh_hlds_windows.ps1",
    ROOT / "deploy" / "install_admin_tools_windows.ps1",
    ROOT / "deploy" / "uninstall_windows.ps1",
    ROOT / ".github" / "workflows" / "compile.yml",
]

errors: list[str] = []
for path in required_files:
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")

source_files = sorted((ROOT / "src").glob("*.sma")) if (ROOT / "src").is_dir() else []
if len(source_files) < 3:
    errors.append("expected trap, detector, and admin tools sources")

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
        "server_cmd(\"quit",
    )
    for call in forbidden_calls:
        if call in lowered:
            errors.append(f"{source_path.relative_to(ROOT)}: forbidden call found: {call}")


def check_commands(path: Path, commands: tuple[str, ...]) -> None:
    if not path.is_file():
        return

    source = path.read_text(encoding="utf-8")
    for command in commands:
        if command not in source:
            errors.append(f"{path.name}: missing admin command: {command}")


check_commands(
    TRAP_SOURCE,
    (
        "amx_trap",
        "amx_untrap",
        "amx_trap_id",
        "amx_untrap_id",
        "amx_trap_list",
        "amx_trap_start",
        "amx_trap_stop",
    ),
)

check_commands(
    DETECTOR_SOURCE,
    (
        "amx_ac_status",
        "amx_ac_reset",
        "amx_ac_mode",
        "amx_ac_testtrap",
    ),
)

check_commands(
    ADMIN_SOURCE,
    (
        "amx_ac_esp",
        "amx_ac_esp_mode",
        "amx_ac_aim",
        "amx_ac_binds",
    ),
)

if TRAP_SOURCE.is_file():
    trap_source = TRAP_SOURCE.read_text(encoding="utf-8")
    for guard in (
        "!g_trapped[id]",
        "hldm_trap_protect_admins",
        "hldm_trap_allow_self",
        "hldm_trap_allow_bots",
        'AutoExecConfig(true, "hldm_trap")',
    ):
        if guard not in trap_source:
            errors.append(f"hldm_trap.sma: missing safety contract: {guard}")

if DETECTOR_SOURCE.is_file():
    detector_source = DETECTOR_SOURCE.read_text(encoding="utf-8")
    for guard in (
        "hldm_ac_minimum_categories",
        "hldm_ac_minimum_events",
        "hldm_ac_exempt_admins",
        'AutoExecConfig(true, "hldm_detector")',
        'server_cmd("amx_trap #%d"',
        "get_uc(userCmd, UC_ViewAngles",
        "create_tr2()",
        "free_tr2(",
    ):
        if guard not in detector_source:
            errors.append(f"hldm_detector.sma: missing detector contract: {guard}")

if ADMIN_SOURCE.is_file():
    admin_source = ADMIN_SOURCE.read_text(encoding="utf-8")
    for guard in (
        'AutoExecConfig(true, "hldm_admin_tools")',
        "MSG_ONE_UNRELIABLE",
        "is_user_admin(viewer)",
        'server_cmd("amx_trap #%d"',
        'server_cmd("amx_untrap #%d"',
    ):
        if guard not in admin_source:
            errors.append(f"hldm_admin_tools.sma: missing local-admin contract: {guard}")


def registered_cvars(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return set(re.findall(r'register_cvar\("([a-z0-9_]+)"', path.read_text(encoding="utf-8")))


def configured_cvars(path: Path, prefix: str) -> set[str]:
    if not path.is_file():
        return set()
    return set(
        re.findall(
            rf'^\s*({re.escape(prefix)}[a-z0-9_]+)\s+',
            path.read_text(encoding="utf-8"),
            re.MULTILINE,
        )
    )


source_config_pairs = (
    (TRAP_SOURCE, TRAP_CONFIG, "hldm_trap_"),
    (DETECTOR_SOURCE, DETECTOR_CONFIG, "hldm_ac_"),
    (ADMIN_SOURCE, ADMIN_CONFIG, "hldm_admin_"),
)

for source_path, config_path, prefix in source_config_pairs:
    registered = registered_cvars(source_path)
    configured = configured_cvars(config_path, prefix)

    missing_in_config = sorted(registered - configured)
    unknown_in_config = sorted(configured - registered)

    if missing_in_config:
        errors.append(f"{config_path.name}: cvars missing in config: " + ", ".join(missing_in_config))
    if unknown_in_config:
        errors.append(f"{config_path.name}: unregistered cvars: " + ", ".join(unknown_in_config))

old_config = ROOT / "configs" / "hldm_trap.cfg"
if old_config.exists():
    errors.append("obsolete config path exists; AutoExecConfig loads configs/plugins/*.cfg")

workflow = ROOT / ".github" / "workflows" / "compile.yml"
if workflow.is_file():
    workflow_text = workflow.read_text(encoding="utf-8")
    for expected in ("src\\*.sma", "build/*.amxx", "Expected at least trap and detector sources"):
        if expected not in workflow_text:
            errors.append(f"compile.yml: expected packaging/build token missing: {expected}")

if errors:
    print("CONTRACT CHECK FAILED")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

all_cvars: set[str] = set()
for source_path, _, _ in source_config_pairs:
    all_cvars |= registered_cvars(source_path)

print(f"Contract check passed: {len(source_files)} source file(s), {len(all_cvars)} cvar(s).")
