"""Export a local Xcode project and compile unsigned iOS builds on macOS.

No Apple account, signing certificate or global xcode-select change is needed.
The generated .app is a compile check, not a signed installable iPhone package.
"""
from __future__ import annotations

import argparse
import os
import platform
import plistlib
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build" / "ios"
PROJECT = OUTPUT / "Hotline.xcodeproj"
PRESET = "iOS Xcode Project"


def run(command: list[str], env: dict[str, str], *, capture: bool = False) -> str:
    result = subprocess.run(command, cwd=ROOT, env=env, check=True,
                            text=True, stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else ""


def environment() -> tuple[str, dict[str, str]]:
    if sys.platform != "darwin":
        raise RuntimeError("iOS export requires macOS and the full Xcode app.")
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
    if not godot:
        raise RuntimeError("Godot is missing. Install Godot 4.7+ or set GODOT_BIN.")
    env = os.environ.copy()
    if not env.get("DEVELOPER_DIR"):
        candidate = Path("/Applications/Xcode.app/Contents/Developer")
        if candidate.is_dir():
            env["DEVELOPER_DIR"] = str(candidate)
    version = run([godot, "--version"], env, capture=True)
    match = re.match(r"(\d+\.\d+(?:\.\d+)?\.(?:stable|beta\d+|rc\d+|dev\d+))", version)
    if not match:
        raise RuntimeError(f"Cannot identify export template version: {version}")
    template = (Path.home() / "Library/Application Support/Godot/export_templates"
                / match.group(1) / "ios.zip")
    if not template.is_file():
        raise RuntimeError(f"Missing matching iOS export template: {template}\n"
                           "Install this Godot version's export templates first.")
    print(f"Godot: {version}\niOS template: {template}", flush=True)
    print(run(["xcodebuild", "-version"], env, capture=True), flush=True)
    for sdk in ("iphoneos", "iphonesimulator"):
        print(f"{sdk}: " + run(["xcrun", "--sdk", sdk, "--show-sdk-path"], env, capture=True), flush=True)
    return godot, env


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check Godot, Xcode and SDKs only (default).")
    parser.add_argument("--export", action="store_true", help="Export the unsigned Xcode project.")
    parser.add_argument("--build", choices=("simulator", "device"), help="Export, then compile without signing.")
    args = parser.parse_args()
    try:
        godot, env = environment()
        if args.export or args.build:
            OUTPUT.mkdir(parents=True, exist_ok=True)
            (OUTPUT.parent / ".gdignore").touch(exist_ok=True)
            # Project-files-only preset: never invokes archive/sign/distribution.
            run([godot, "--headless", "--path", str(ROOT), "--export-debug", PRESET, str(PROJECT)], env)
            if not PROJECT.is_dir() or not (OUTPUT / "Hotline.pck").is_file():
                raise RuntimeError("Export did not produce the Xcode project and game pack.")
            print(f"Xcode project: {PROJECT}", flush=True)
        if args.build:
            simulator = args.build == "simulator"
            architecture = "arm64"
            if simulator:
                info = OUTPUT / "Hotline.xcframework" / "Info.plist"
                with info.open("rb") as file:
                    frameworks = plistlib.load(file)["AvailableLibraries"]
                variant = next(entry for entry in frameworks
                               if entry.get("SupportedPlatformVariant") == "simulator")
                library = info.parent / variant["LibraryIdentifier"] / variant["LibraryPath"]
                # Some template archives advertise both architectures but contain
                # an x86_64-only .a. Inspect the actual binary before linking.
                supported = run(["xcrun", "lipo", "-archs", str(library)], env, capture=True).split()
                native = "arm64" if platform.machine() == "arm64" else "x86_64"
                architecture = native if native in supported else next(
                    (arch for arch in ("arm64", "x86_64") if arch in supported), "")
                if not architecture:
                    raise RuntimeError("No supported iOS simulator architecture in the export template.")
                if architecture != native:
                    print(f"Template simulator library is {architecture}; this is a cross-compile check, "
                          "not native Apple Silicon simulator validation.", flush=True)
            run(["xcodebuild", "-project", str(PROJECT), "-scheme", "Hotline",
                 "-configuration", "Debug", "-sdk", "iphonesimulator" if simulator else "iphoneos",
                 "-destination", "generic/platform=iOS Simulator" if simulator else "generic/platform=iOS",
                 "-derivedDataPath", str(OUTPUT / args.build), "CODE_SIGNING_ALLOWED=NO",
                 "CODE_SIGNING_REQUIRED=NO", "DEVELOPMENT_TEAM=", f"ARCHS={architecture}",
                 "ONLY_ACTIVE_ARCH=NO", "build"], env)
            print("Unsigned build complete. iPhone installation still requires your real signing Team.", flush=True)
        return 0
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"iOS build failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
