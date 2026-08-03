#!/usr/bin/env python3
from pathlib import Path

path = Path("src/hldm_detector.sma")
text = path.read_text(encoding="utf-8")
old = "for (new SignalType:signal = Signal_SnapFire; signal < _:Signal_Count; signal++)"
new = "for (new SignalType:signal = Signal_SnapFire; signal < Signal_Count; signal++)"
fixed = text.replace(old, new)
if fixed == text:
    print("No detector tag fix needed.")
else:
    path.write_text(fixed, encoding="utf-8", newline="\n")
    print("Detector enum tag comparisons fixed.")
