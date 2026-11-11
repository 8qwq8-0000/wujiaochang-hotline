#!/usr/bin/env python3
"""Run separate Godot processes and fail on any cleanup/runtime diagnostic."""
import argparse
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--windowed', action='store_true', help='Also exercise the graphical renderer/audio driver')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
logs = pathlib.Path(tempfile.mkdtemp(prefix='hotline-shutdown-'))
failed = 0
for mode in ('menu', 'window', 'paused', 'loading', 'scene_loader'):
    command = ['godot', '--verbose', '--path', str(root)]
    if not args.windowed:
        command += ['--headless', '--fixed-fps', '60']
    command += ['--script', 'res://tests/integration/shutdown_check.gd', '--', '--shutdown-mode=' + mode]
    log = logs / (mode + '.log')
    try:
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=root, stdout=stream, stderr=subprocess.STDOUT, timeout=45)
        lines = log.read_text(errors='replace').splitlines()
        diagnostics = [line for line in lines if line.startswith(('WARNING:', 'ERROR:', 'SCRIPT ERROR:'))
                       or any(token in line for token in ('Leaked instance:', 'still in use at exit', 'RID allocations'))]
        ok = result.returncode == 0 and not diagnostics and any('Shutdown check:' in line for line in lines)
    except subprocess.TimeoutExpired:
        diagnostics = ['timed out']
        ok = False
    print(f'{mode}: {"PASS" if ok else "FAIL"} ({log})', flush=True)
    for diagnostic in diagnostics:
        print('  ' + diagnostic, flush=True)
    failed += not ok
print(f'{5 - failed}/5 clean exits; logs: {logs}')
raise SystemExit(bool(failed))
