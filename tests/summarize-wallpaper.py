"""Summarize exported wallpaper probes without treating missing data as zero."""
import argparse
import csv
import json
import statistics
from datetime import datetime, timedelta
from pathlib import Path


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def percentile(values, fraction):
    values = sorted(values)
    return values[min(len(values) - 1, int(len(values) * fraction))] if values else None


def summarize(folder):
    metadata = read_json(folder / "hardware.json")
    results = read_json(folder / "results.json")
    timing = read_json(folder / "sample-times.json")
    with (folder / "process.csv").open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    power = []
    gpu_file = folder / "whole-gpu.csv"
    run_start = datetime.fromisoformat(timing["run_started"])
    if gpu_file.exists():
        with gpu_file.open(encoding="utf-8-sig", newline="") as handle:
            for row in csv.reader(handle):
                try:
                    stamp = datetime.strptime(row[0].strip(), "%Y/%m/%d %H:%M:%S.%f").replace(tzinfo=run_start.tzinfo)
                    power.append((stamp, float(row[4]), float(row[6])))
                except (ValueError, IndexError):
                    continue  # nvidia-smi repeats its header; unavailable is not 0 W.
    before = [p[1] for p in power if p[0] < run_start - timedelta(seconds=5)]
    after_start = datetime.fromisoformat(timing["after_started"])
    after = [p[1] for p in power if p[0] > after_start + timedelta(seconds=10)]
    idle_values = before + after
    idle = statistics.mean(idle_values) if idle_values else None
    cases = []
    for case in results["cases"]:
        group = [r for r in rows if r["phase"] == case["case"]]
        duration = sum(float(b["elapsed"]) - float(a["elapsed"]) for a, b in zip(group, group[1:]))
        cpu = sum(max(0, float(b["cpu_total_ms"]) - float(a["cpu_total_ms"])) for a, b in zip(group, group[1:]))
        measured_power = []
        if len(group) > 1:
            # The status file updates every two seconds. Trim phase boundaries.
            start = run_start + timedelta(seconds=float(group[0]["elapsed"]) + 3)
            end = run_start + timedelta(seconds=float(group[-1]["elapsed"]) - 3)
            measured_power = [p for p in power if start <= p[0] <= end]
        watts = statistics.mean(p[1] for p in measured_power) if measured_power else None
        item = {
            "case": case["case"], "seconds": case["seconds"],
            "drawn_frames": case["drawn_frames"], "covered_seconds": case.get("covered_seconds"),
            "frame_interval_ms": case["interval_ms"],
            "cpu_ms_per_second": cpu / duration if duration else None,
            "working_set_p95_mib": percentile([float(r["working_set"]) / 1048576 for r in group], .95),
            "private_p95_mib": percentile([float(r["private_bytes"]) / 1048576 for r in group], .95),
            "system_gpu_dedicated_p95_mib": percentile([float(r["gpu_dedicated"]) / 1048576 for r in group if r["gpu_dedicated"]], .95),
            "texture_and_buffer_mib": (case["texture_memory"] + case["buffer_memory"]) / 1048576,
            "board_power_mean_w": watts,
            "incremental_power_w": watts - idle if watts is not None and idle is not None else None,
            "gpu_clock_mean_mhz": statistics.mean(p[2] for p in measured_power) if measured_power else None,
            "primitives": case["primitives"], "shadow_primitives": case["shadow_primitives"],
            "draw_calls": case["draw_calls"], "resources": case["resources"], "nodes": case["nodes"],
            "pipeline_compilations": case.get("pipeline_compilations"),
        }
        for owner in ("game", "host"):
            column = owner + "_cpu_total_ms"
            item[owner + "_cpu_ms_per_second"] = (
                sum(max(0, float(b[column]) - float(a[column])) for a, b in zip(group, group[1:])) / duration
                if duration and all(r.get(column) for r in group) else None
            )
        cases.append(item)
    actions = folder / "actions.json"
    soak = [r for r in rows if r["phase"].startswith("soak_")]
    growth = None
    if len(soak) > 1:
        beginning = [float(r["working_set"]) for r in soak if float(r["elapsed"]) < float(soak[0]["elapsed"]) + 180]
        ending = [float(r["working_set"]) for r in soak if float(r["elapsed"]) > float(soak[-1]["elapsed"]) - 180]
        growth = (statistics.median(ending) - statistics.median(beginning)) / 1048576
    return {
        "evidence": str(folder.resolve()), "hardware": metadata,
        "startup": read_json(folder / "ready.json"),
        "idle_power_mean_w": idle,
        "idle_before_mean_w": statistics.mean(before) if before else None,
        "idle_after_mean_w": statistics.mean(after) if after else None,
        "idle_p05_p95_w": [percentile(idle_values, .05), percentile(idle_values, .95)],
        "actions_p95_ms": percentile([x["ms"] for x in read_json(actions)], .95) if actions.exists() else None,
        "resume": {p.stem: read_json(p) for p in folder.glob("resume*.json")},
        "soak_sample_span_hours": (float(soak[-1]["elapsed"]) - float(soak[0]["elapsed"])) / 3600 if soak else None,
        "soak_working_set_growth_mib": growth,
        "cases": cases, "failures": results["failures"],
        "note": "Local measurements only. Hardware/quality/output resolution must match before comparing; GPU board power includes other applications.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, nargs="+")
    args = parser.parse_args()
    for directory in args.directory:
        report = summarize(directory)
        (directory / "summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False, indent=2))
