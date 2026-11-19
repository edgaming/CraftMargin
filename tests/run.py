"""Run Craft Margin's tests: python tests/run.py [filter]

Each test runs in a fresh Lua 5.1 runtime (lupa) with tests/wowmock.lua and the addon
files loaded in .toc order.
"""
import glob
import os
import re
import sys

import lupa.lua51 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = "CraftMargin"


def toc_files():
    files, version = [], None
    with open(os.path.join(ROOT, ADDON + ".toc"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            m = re.match(r"## Version:\s*(\S+)", line)
            if m:
                version = m.group(1)
            if line and not line.startswith("#"):
                files.append(line.replace("\\", "/"))
    return files, version


def glyph_problems(files):
    """Text the player sees must use characters WoW's default font has (roughly Windows-1252);
    anything else, like an arrow, draws as an empty box."""
    problems = []
    for path in files:
        if path.endswith("Data.lua") or path.endswith("RecipeSources.lua"):
            continue
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            for n, line in enumerate(f, start=1):
                code = line.split("--", 1)[0]
                for ch in code:
                    if ord(ch) > 127:
                        try:
                            ch.encode("cp1252")
                        except UnicodeEncodeError:
                            problems.append(f"{path}:{n}: {ch!r} (U+{ord(ch):04X}) isn't in the game font")
    return problems


def runtime(files, test_file):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_DIR = ROOT
    g.TOC_FILES = lua.table_from(files)
    lua.execute(open(os.path.join(ROOT, "tests", "wowmock.lua"), encoding="utf-8").read())
    lua.execute(open(test_file, encoding="utf-8").read())
    return lua


def main():
    flt = sys.argv[1] if len(sys.argv) > 1 else ""
    files, version = toc_files()
    with open(os.path.join(ROOT, "VERSION")) as f:
        expected = f.read().strip()
    failures, count = [], 0
    if version not in (expected, "@project-version@"):
        failures.append(("toc", f"## Version {version} != VERSION {expected}"))
    for problem in glyph_problems(files):
        failures.append(("toc", problem))

    for test_file in sorted(glob.glob(os.path.join(ROOT, "tests", "t_*.lua"))):
        base = os.path.basename(test_file)
        names = [t["name"] for t in runtime(files, test_file).globals().TESTS.values()]
        for i, name in enumerate(names, start=1):
            full = f"{base}: {name}"
            if flt and flt not in full:
                continue
            count += 1
            lua = runtime(files, test_file)
            res = lua.eval(
                "function(i) return xpcall(TESTS[i].fn, function(e) return debug.traceback(tostring(e), 2) end) end"
            )(i)
            okay, err = (res, None) if res is True else res
            if okay:
                print(f"  ok    {full}")
            else:
                print(f"  FAIL  {full}\n{err}")
                failures.append((full, err))

    print(f"\n{count - len([f for f in failures if f[0] != 'toc'])}/{count} passed")
    for name, err in failures:
        if name == "toc":
            print("FAIL", err)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
