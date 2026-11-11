#!/usr/bin/env python3
"""Run separate Godot processes and fail on any cleanup/runtime diagnostic."""
import argparse
import os
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--windowed', action='store_true', help='Also exercise the graphical renderer/audio driver')
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
parser.add_argument("--output", type=pathlib.Path, help="Keep logs in this directory")
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
logs = args.output.resolve() if args.output else pathlib.Path(tempfile.mkdtemp(prefix='hotline-shutdown-'))
logs.mkdir(parents=True, exist_ok=True)
failed = 0
modes = ('menu', 'window', 'paused', 'loading', 'scene_loader', 'boss', 'channel')
for mode in modes:
    command = [args.godot, '--verbose', '--path', str(root)]
    if not args.windowed:
        command += ['--headless', '--fixed-fps', '60']
    command += ['--script', 'res://tests/integration/shutdown_check.gd', '--', '--shutdown-mode=' + mode]
    log = logs / (mode + '.log')
    try:
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=root, stdout=stream, stderr=subprocess.STDOUT, timeout=45)
        lines = log.read_text(errors='replace').splitlines()
        diagnostics = [line for line in lines if line.startswith(('WARNING:', 'ERROR:', 'SCRIPT ERROR:'))
                       or any(token in line for token in ('Leaked instance:', 'still in use at exit', 'RID allocations', 'Orphan StringName:', 'unclaimed string names'))]
        ok = result.returncode == 0 and not diagnostics and any('Shutdown check:' in line for line in lines)
    except subprocess.TimeoutExpired:
        diagnostics = ['timed out']
        ok = False
    print(f'{mode}: {"PASS" if ok else "FAIL"} ({log})', flush=True)
    for diagnostic in diagnostics:
        print('  ' + diagnostic, flush=True)
    failed += not ok
print(f'{len(modes) - failed}/{len(modes)} clean exits; logs: {logs}')
raise SystemExit(bool(failed))
