#!/usr/bin/env python3
from pathlib import Path

path = Path("src/hldm_detector.sma")
text = path.read_text(encoding="utf-8")

replacements = {
    "ClampInt(get_pcvar_num(g_pcvarMinimumCategories), 1, Signal_Count)": "ClampInt(get_pcvar_num(g_pcvarMinimumCategories), 1, _:Signal_Count)",
    "new Float:forward[3], Float:right[3], Float:up[3];": "new Float:forwardVector[3], Float:rightVector[3], Float:upVector[3];",
    "engfunc(EngFunc_AngleVectors, angles, forward, right, up);": "engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);",
    "DotProduct(forward, direction)": "DotProduct(forwardVector, direction)",
    "new Float:eye[3], Float:forward[3], Float:right[3], Float:up[3], Float:end[3];": "new Float:eye[3], Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:traceEnd[3];",
    "end[0] = eye[0] + forward[0] * 8192.0;": "traceEnd[0] = eye[0] + forwardVector[0] * 8192.0;",
    "end[1] = eye[1] + forward[1] * 8192.0;": "traceEnd[1] = eye[1] + forwardVector[1] * 8192.0;",
    "end[2] = eye[2] + forward[2] * 8192.0;": "traceEnd[2] = eye[2] + forwardVector[2] * 8192.0;",
    "engfunc(EngFunc_TraceLine, eye, end, DONT_IGNORE_MONSTERS, id, trace);": "engfunc(EngFunc_TraceLine, eye, traceEnd, DONT_IGNORE_MONSTERS, id, trace);",
    "stock bool:CanSeeTarget(id, target, const Float:start[3], const Float:end[3])": "stock bool:CanSeeTarget(id, target, const Float:traceStart[3], const Float:traceEnd[3])",
    "engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, id, trace);": "engfunc(EngFunc_TraceLine, traceStart, traceEnd, DONT_IGNORE_MONSTERS, id, trace);",
    "signal < Signal_Count": "signal < _:Signal_Count",
    "bit < Signal_Count": "bit < _:Signal_Count",
    "for (new signal = 0; signal < _:Signal_Count; signal++)": "for (new SignalType:signal = Signal_SnapFire; signal < Signal_Count; signal++)",
}

changed = False
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)
        changed = True

if changed:
    path.write_text(text, encoding="utf-8", newline="\n")
    print("Detector source patched.")
else:
    print("No detector patch needed.")
