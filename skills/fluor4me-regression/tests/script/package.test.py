"""Check a Fluor4me app built from this checkout on macOS."""

import argparse
from pathlib import Path
import plistlib
import re
import subprocess


def test_PKG_01(app: Path) -> None:
    source = Path(__file__).resolve().parents[4] / "Fluor"
    contents = app / "Contents"
    resources = contents / "Resources"
    expected = plistlib.loads((source / "Info.plist").read_bytes())
    actual = plistlib.loads((contents / "Info.plist").read_bytes())
    for key in (
        "CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
        "CFBundleExecutable", "LSMinimumSystemVersion", "LSUIElement",
    ):
        assert actual.get(key) == expected[key], f"{key}: expected {expected[key]}, got {actual.get(key)}"

    executable = contents / "MacOS" / expected["CFBundleExecutable"]
    subprocess.run(["/usr/bin/codesign", "--verify", "--strict", app], check=True)
    architectures = subprocess.check_output(["lipo", "-archs", executable], text=True).split()
    assert architectures == ["arm64"], f"Expected arm64 only, got {architectures}"
    build = subprocess.check_output(
        ["xcrun", "vtool", "-arch", "arm64", "-show-build", executable], text=True,
    )
    minimum = re.search(r"^\s*minos\s+(\S+)", build, re.MULTILINE)
    assert minimum and minimum[1] == expected["LSMinimumSystemVersion"], build

    icons = sorted(path.name for path in (source / "MenuBarIcons").glob("*.png"))
    for name in ["AppIcon.icns", "GitHubMark.pdf", "LICENSE", "DefaultsWrapper-LICENSE", *icons]:
        path = resources / name
        assert path.is_file() and path.stat().st_size, f"Missing or empty resource: {name}"
    for locale in ("en", "zh-Hans"):
        subprocess.run(["plutil", "-lint", resources / f"{locale}.lproj/Localizable.strings"], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="path to the candidate .app")
    print("[PKG-01] Checking candidate app", flush=True)
    test_PKG_01(parser.parse_args().app)
    print("[PKG-01] Passed")
