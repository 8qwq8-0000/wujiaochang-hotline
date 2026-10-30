"""Build a signed, non-debug Android preview APK from Godot's prebuilt template.

The persistent local signing key and credentials stay outside the repository.
No Gradle project or extra native Android plugins are needed by this game.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APK_NAME = "wujiaochang-hotline-android-v0.1.1-mobile-preview.1.apk"
OUTPUT = ROOT / "build/android" / APK_NAME
SIGNING_DIR = Path.home() / ".codex/app-signing/wujiaochang-hotline"


def signing(env: dict[str, str], java: Path) -> dict[str, str]:
    config = SIGNING_DIR / "android-release.json"
    if config.exists():
        data = json.loads(config.read_text())
        if not Path(data["keystore"]).is_file():
            raise RuntimeError("The existing Android signing key is missing; restore it before building updates.")
        return data
    SIGNING_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = SIGNING_DIR / "android-release.p12"
    if key.exists():
        raise RuntimeError("Signing key exists without its configuration; restore the credentials rather than replacing the key.")
    data = {"keystore": str(key), "alias": "hotline", "password": secrets.token_urlsafe(32)}
    key_env = env.copy()
    key_env["HOTLINE_ANDROID_SIGN_PASSWORD"] = data["password"]
    subprocess.run([str(java / "bin/keytool"), "-genkeypair", "-storetype", "PKCS12",
                    "-keystore", str(key), "-alias", data["alias"],
                    "-storepass:env", "HOTLINE_ANDROID_SIGN_PASSWORD",
                    "-keypass:env", "HOTLINE_ANDROID_SIGN_PASSWORD",
                    "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
                    "-dname", "CN=Wujiaochang Hotline,OU=Game Development,O=Wujiaochang Hotline,C=CN"],
                   check=True, env=key_env)
    key.chmod(0o600)
    with os.fdopen(os.open(config, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as file:
        json.dump(data, file)
    print(f"Created persistent local signing key: {key}", flush=True)
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, default=Path.home() / "Library/Android/sdk")
    parser.add_argument("--java-home", type=Path, default=Path("/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"))
    args = parser.parse_args()
    try:
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
        if not godot:
            raise RuntimeError("Install Godot 4.7+ or set GODOT_BIN.")
        tools = args.sdk / "build-tools/36.0.0"
        if not (tools / "apksigner").is_file() or not (args.sdk / "platform-tools/adb").is_file():
            raise RuntimeError("Install Android platform-tools and build-tools 36.0.0 in the configured SDK directory.")
        env = os.environ.copy()
        env["JAVA_HOME"] = str(args.java_home)
        env["ANDROID_HOME"] = str(args.sdk)
        env["ANDROID_SDK_ROOT"] = str(args.sdk)
        data = signing(env, args.java_home)
        env.update({"GODOT_ANDROID_KEYSTORE_RELEASE_PATH": data["keystore"],
                    "GODOT_ANDROID_KEYSTORE_RELEASE_USER": data["alias"],
                    "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": data["password"]})
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        (OUTPUT.parent.parent / ".gdignore").touch(exist_ok=True)
        subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-release",
                        "Android Preview APK", str(OUTPUT)], cwd=ROOT, env=env, check=True)
        if not OUTPUT.is_file():
            raise RuntimeError("Godot did not produce the APK.")
        with zipfile.ZipFile(OUTPUT) as archive:
            bad = archive.testzip()
            if bad:
                raise RuntimeError("APK ZIP integrity failure: " + bad)
        subprocess.run([str(tools / "apksigner"), "verify", "--verbose", "--print-certs", str(OUTPUT)], env=env, check=True)
        with OUTPUT.open("rb") as file:
            digest = hashlib.file_digest(file, "sha256").hexdigest()
        checksum = OUTPUT.with_suffix(".apk.sha256")
        checksum.write_text(f"{digest}  {OUTPUT.name}\n")
        print(f"APK: {OUTPUT}\nSHA-256: {digest}\nChecksum: {checksum}", flush=True)
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Android build failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
