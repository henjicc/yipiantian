"""Decode adopted runtime assets and check peaks, DC, and loop boundaries."""
from pathlib import Path
import json
import re
import subprocess
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[2]
reports = []
for path in sorted((ROOT / "Game/art/audio").iterdir()):
    if path.suffix not in (".wav", ".ogg"):
        continue
    data, rate = sf.read(path, always_2d=True)
    oversampled = resample_poly(data, 4, 1, axis=0)
    delta = np.max(abs(np.diff(data, axis=0)))
    seam = np.max(abs(data[0] - data[-1]))
    result = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "loudnorm=I=-24:TP=-2:LRA=11:print_format=json", "-f", "null", "-"], capture_output=True, text=True, encoding="utf-8", check=True)
    meter = json.loads(re.search(r'\{\s*"input_i".*?\}', result.stderr, re.S).group())
    reports.append({"file": str(path.relative_to(ROOT)), "duration": len(data) / rate,
                    "integrated_lufs": meter["input_i"], "true_peak_dbfs": float(20 * np.log10(max(abs(oversampled).max(), 1e-12))),
                    "dc_peak": float(abs(data.mean(axis=0)).max()), "loop_seam_delta": float(seam),
                    "max_adjacent_delta": float(delta), "seam_below_normal_peak_delta": bool(seam <= delta),
                    "clipped_samples": int(np.sum(abs(data) >= 1)), "finite": bool(np.isfinite(data).all())})
    if path.suffix == ".ogg":
        join = np.concatenate([data[-8 * rate:], data[:8 * rate]])
        target = ROOT / ".local/atmosphere-audio" / (path.stem + "-loop-join.wav")
        target.parent.mkdir(parents=True, exist_ok=True)
        sf.write(target, join, rate, subtype="PCM_16")
assert all(r["finite"] and r["clipped_samples"] == 0 and r["true_peak_dbfs"] < -2 for r in reports)
assert all(r["seam_below_normal_peak_delta"] for r in reports)
(ROOT / "ArtSource/Audio/validation-report.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
print(json.dumps(reports, indent=2))
