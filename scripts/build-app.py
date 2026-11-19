#!/usr/bin/env python3
"""Build and sign the Fluor4me app using the macOS Command Line Tools."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
FLUOR = ROOT / "Fluor"
# DefaultsWrapper 1.2.0, from the previous Xcode project's Package.resolved.
DEFAULTS_REVISION = "649794e5c7af45f69d1e128a3c9fd0fe1cde282e"


def run(*args):
    subprocess.run(args, check=True)


def copy_app_icon(resources, scratch):
    assets = FLUOR / "Assets.xcassets"
    original = assets / "AppIcon.appiconset"
    iconset = scratch / "AppIcon.iconset"
    iconset.mkdir()
    for entry in json.loads((original / "Contents.json").read_text())["images"]:
        scale = "" if entry["scale"] == "1x" else "@" + entry["scale"]
        shutil.copyfile(original / entry["filename"], iconset / f'icon_{entry["size"]}{scale}.png')
    run("iconutil", "-c", "icns", "-o", resources / "AppIcon.icns", iconset)


def build(output, identity, debug, scratch):
    app = scratch / output.name
    contents = app / "Contents"
    resources = contents / "Resources"
    binaries = contents / "MacOS"
    resources.mkdir(parents=True)
    binaries.mkdir()

    info = plistlib.loads((FLUOR / "Info.plist").read_bytes())
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    copy_app_icon(resources, scratch)
    for icon in (FLUOR / "MenuBarIcons").glob("*.png"):
        shutil.copyfile(icon, resources / icon.name)
    shutil.copyfile(FLUOR / "GitHubMark.pdf", resources / "GitHubMark.pdf")
    for translations in sorted(FLUOR.glob("*.lproj/Localizable.strings")):
        destination = resources / translations.parent.name
        destination.mkdir()
        shutil.copyfile(translations, destination / translations.name)
    shutil.copyfile(ROOT / "LICENSE", resources / "LICENSE")

    archive = scratch / "DefaultsWrapper.tar.gz"
    run("curl", "--fail", "--silent", "--show-error", "--location", "--retry", "2",
        f"https://codeload.github.com/Pyroh/DefaultsWrapper/tar.gz/{DEFAULTS_REVISION}",
        "-o", archive)
    run("tar", "-xzf", archive, "-C", scratch)
    dependency = scratch / f"DefaultsWrapper-{DEFAULTS_REVISION}"
    shutil.copyfile(dependency / "LICENSE", resources / "DefaultsWrapper-LICENSE")
    library = dependency / "Sources" / "DefaultsWrapper"
    compiler = [
        "xcrun", "swiftc", "-target", f'arm64-apple-macosx{info["LSMinimumSystemVersion"]}',
        "-swift-version", "5",
    ]
    flags = ["-Onone", "-DDEBUG"] if debug else ["-O", "-whole-module-optimization"]
    run(*compiler, *flags, "-module-name", "DefaultsWrapper", "-emit-module",
        "-emit-module-path", scratch / "DefaultsWrapper.swiftmodule",
        "-emit-library", "-static", "-o", scratch / "libDefaultsWrapper.a",
        *sorted(library.rglob("*.swift")))
    run(*compiler, *flags, "-module-name", "Fluor", "-I", scratch, "-L", scratch,
        "-lDefaultsWrapper", "-o", binaries / info["CFBundleExecutable"],
        *sorted(FLUOR.rglob("*.swift")))
    run("codesign", "--force", "--options", "runtime", "--sign", identity,
        "--entitlements", FLUOR / "Fluor.entitlements", app)
    run("codesign", "--verify", "--strict", app)
    app.rename(output)


def trash(path):
    tool = shutil.which("trash")
    if tool:
        run(tool, path)
    else:
        run("osascript", "-l", "JavaScript", "-e", """
ObjC.import('Foundation')
function run(argv) {
    const url = $.NSURL.fileURLWithPath(argv[0])
    if (!$.NSFileManager.defaultManager.trashItemAtURLResultingItemURLError(url, null, null)) {
        throw Error('Could not trash ' + argv[0])
    }
}
""", path)


def local_signing_identity():
    """Use the Mac's development identity to keep the app recognizable across local builds."""
    result = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"],
                            capture_output=True, text=True, check=True)
    identities = re.findall(r'^\s*\d+\) ([0-9A-Fa-f]{40}) "Apple Development:', result.stdout, re.MULTILINE)
    return identities[0] if len(identities) == 1 else "-"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "Fluor4me.app")
    parser.add_argument("--sign", help="codesign identity (default: local Apple Development identity if unique, otherwise ad hoc)")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()
    output = args.output.absolute()
    if output.suffix != ".app":
        parser.error("--output must end in .app")
    if os.path.lexists(output):
        parser.error(f"output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix=".fluor-build-", dir=output.parent))
    try:
        build(output, args.sign or local_signing_identity(), args.debug, scratch)
    finally:
        trash(scratch)
    print(output)


if __name__ == "__main__":
    main()
