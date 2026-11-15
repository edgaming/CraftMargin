"""Build dist/CraftMargin-<version>.zip with a single top folder CraftMargin/.

Usage: python3 tools/package.py
"""
import os
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = "CraftMargin"
INCLUDE = [ADDON + ".toc", "Commands.lua", "Core", "Domain", "UI", "Media"]


def main():
    version = open(os.path.join(ROOT, "VERSION")).read().strip()
    out_dir = os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{ADDON}-{version}.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for item in INCLUDE:
            path = os.path.join(ROOT, item)
            if os.path.isfile(path):
                z.write(path, f"{ADDON}/{item}")
                continue
            for base, _, files in os.walk(path):
                for name in sorted(files):
                    full = os.path.join(base, name)
                    rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
                    z.write(full, f"{ADDON}/{rel}")
    print(out)


if __name__ == "__main__":
    main()
