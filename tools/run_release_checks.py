"""Run the curated game regression profiles and preserve per-check evidence."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tests" / "release_manifest.json"


def find_godot(explicit: str | None) -> str:
    candidate = explicit or os.environ.get("GODOT_BIN") or shutil.which("godot")
    if not candidate:
        raise ValueError("Set GODOT_BIN or pass --godot with the Godot 4.7.2 executable")
    if not Path(candidate).is_file() and not shutil.which(candidate):
        raise ValueError(f"Godot executable not found: {candidate}")
    return candidate


def git_revision() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def working_tree_dirty() -> bool:
    result = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    return result.returncode != 0 or bool(result.stdout.strip())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("fast", "candidate"))
    parser.add_argument("--godot", help="Godot executable; also accepts GODOT_BIN")
    parser.add_argument("--timeout", type=int, default=180, help="Seconds allowed per check")
    parser.add_argument("--output", type=Path, help="Report directory; defaults to build/test-reports")
    parser.add_argument("--list", action="store_true", help="Print selected checks without running them")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    selected = list(manifest["fast"])
    if args.profile == "candidate":
        selected += manifest["candidate_extra"]
    if len(selected) != len(set(selected)):
        parser.error("The release manifest contains duplicate checks")
    excluded = set(manifest["historical_exclusions"])
    if excluded.intersection(selected):
        parser.error("A historical exclusion is also selected for release checks")
    missing = [name for name in selected if not (ROOT / name).is_file()]
    if missing:
        parser.error("Missing checks: " + ", ".join(missing))
    if args.list:
        print("\n".join(selected))
        return 0

    try:
        godot = find_godot(args.godot)
    except ValueError as error:
        parser.error(str(error))
    output = ((ROOT / args.output) if args.output else ROOT / "build" / "test-reports").resolve()
    output.mkdir(parents=True, exist_ok=True)
    started = datetime.now(timezone.utc).isoformat()
    results = []
    for index, name in enumerate(selected, 1):
        command = [godot, "--headless", "--path", str(ROOT)]
        if name.endswith("prologue_check.gd"):
            command += ["--fixed-fps", "60"]
        command += ["--script", name]
        print(f"[{index}/{len(selected)}] {name}", flush=True)
        timed_out = False
        try:
            process = subprocess.run(
                command, cwd=ROOT, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=args.timeout, check=False,
            )
            output_text = process.stdout + process.stderr
            exit_code = process.returncode
        except subprocess.TimeoutExpired as error:
            timed_out = True
            stdout = error.stdout or b""
            stderr = error.stderr or b""
            output_text = stdout.decode("utf-8", "replace") if isinstance(stdout, bytes) else stdout
            output_text += stderr.decode("utf-8", "replace") if isinstance(stderr, bytes) else stderr
            exit_code = 124
        log_path = output / (Path(name).stem + ".log")
        log_path.write_text(output_text, encoding="utf-8")
        diagnostics = [line for line in output_text.splitlines()
                       if line.startswith(("ERROR:", "SCRIPT ERROR:"))
                       or any(token in line for token in ("ObjectDB instance", "Leaked instance:", "still in use at exit", "RID allocations"))]
        result = {
            "check": name,
            "status": "timeout" if timed_out else ("passed" if exit_code == 0 and not diagnostics else "failed"),
            "exit_code": exit_code,
            "diagnostics": diagnostics,
            "log": str(log_path.relative_to(ROOT) if log_path.is_relative_to(ROOT) else log_path).replace("\\", "/"),
        }
        results.append(result)
        print(f"  {result['status']} (exit {exit_code})", flush=True)

    report = {
        "profile": args.profile,
        "revision": git_revision(),
        "working_tree_dirty": working_tree_dirty(),
        "started_utc": started,
        "finished_utc": datetime.now(timezone.utc).isoformat(),
        "godot": godot,
        "results": results,
        "passed": sum(row["status"] == "passed" for row in results),
        "failed": sum(row["status"] != "passed" for row in results),
    }
    (output / "results.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{args.profile}: {report['passed']}/{len(results)} checks passed; report: {output / 'results.json'}")
    return 0 if report["failed"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
