"""Looks inside a built APK.

It checks the pieces that matter for the round that was built: the brand
tile of the splash, the launcher icons, the name of the app and the
signature.

Usage:  python tooling/check_apk.py <path to the apk>
"""

from __future__ import annotations

import re
import sys
import zipfile


def main() -> None:
    path = sys.argv[1]
    with zipfile.ZipFile(path) as apk:
        names = apk.namelist()

        print(f"apk: {path}")
        print(f"  entries: {len(names)}")

        assets = [n for n in names if n.startswith("assets/flutter_assets/assets/")]
        print(f"  dart assets: {len(assets)}")
        for asset in sorted(assets):
            print(f"    {asset}")

        icons = [n for n in names if "ic_launcher" in n]
        print(f"  launcher icons: {len(icons)}")

        signatures = [
            n for n in names if n.startswith("META-INF/") and n.endswith(".RSA")
        ]
        print(f"  signature blocks: {len(signatures)}")

        # The label of the application lives in the binary manifest, as UTF-16
        # on the string pool of the resources.
        manifest = apk.read("AndroidManifest.xml")
        if b"Ennvo" in manifest or "Ennvo".encode("utf-16-le") in manifest:
            print("  the name of the app: Ennvo")
        else:
            print("  the name of the app: NOT FOUND")

        # The signature of the release build (v2 / v3) lives in a block
        # before the central directory. Its presence shows up as the marker
        # of the APK signature block.
        with open(path, "rb") as handle:
            head = handle.read(1024 * 1024)
            size = len(head)
            handle.seek(-64, 2)
            tail = handle.read(64)
        if b"APK Sig Block 42" in head or b"APK Sig Block 42" in tail:
            print("  the v2 / v3 signature: present")
        else:
            print("  the v2 / v3 signature: NOT FOUND (the file may be short)")

        # The size of the arm64 library folder tells whether the plugins
        # came along.
        libs = sorted({n.split("/")[1] for n in names if n.startswith("lib/")})
        print(f"  abi folders: {', '.join(libs)}")

        native = [n for n in names if n.startswith("lib/arm64-v8a/")]
        print(f"  arm64 libraries: {len(native)}")
        for lib in sorted(native):
            size = apk.getinfo(lib).file_size / (1024 * 1024)
            print(f"    {lib}  {size:.2f} MB")


if __name__ == "__main__":
    main()
