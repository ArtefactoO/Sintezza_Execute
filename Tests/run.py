"""Compile Execute as Lua 5.1 and verify rendering state without starting WoW."""

from argparse import ArgumentParser
from pathlib import Path
import re
import sys


parser = ArgumentParser(description=__doc__)
parser.add_argument("--runtime", type=Path, help="Directory containing the lupa package")
parser.add_argument("--baseline", type=Path, help="Optional before-refactor addon snapshot")
options = parser.parse_args()
if options.runtime:
    sys.path.insert(0, str(options.runtime.resolve()))

from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(source, path) assert(loadstring(source, path)) end")
files = [file for file in root.rglob("*.lua") if "Tests" not in file.parts and ".git" not in file.parts]
for file in files:
    compile_lua(file.read_text(encoding="utf-8-sig"), str(file))
print(f"PASS: {len(files)} production files compile with {lua.eval('_VERSION')}")

manifest = (root / "Sintezza_Execute.toc").read_text(encoding="utf-8-sig")
version = re.search(r"^## Version:\s*(\S+)", manifest, re.M)[1]
sections = re.findall(r"^## (\S+)", (root / "CHANGELOG.md").read_text(encoding="utf-8-sig"), re.M)
assert next(value for value in sections if value != "Unreleased") == version
assert "16001" in re.search(r"^## Interface:\s*(.+)", manifest, re.M)[1]
for row in manifest.splitlines():
    if row.strip() and not row.startswith("#"):
        assert (root / row.strip().replace("\\", "/")).is_file(), row
print(f"PASS: TOC entries and version {version}")

run = lua.execute((root / "Tests/Nameplates.lua").read_text(encoding="utf-8"))
current = run(root.as_posix())
assert current["ranges"] == 1 and current["values"] == 1
print(f"PASS: rendering, visibility, cooldown and secret-value contracts ({current['assertions']} assertions)")
print("PASS: 40 stable draws write the marker range and threshold once")
if options.baseline:
    before = run(options.baseline.resolve().as_posix())
    assert before["snapshots"] == current["snapshots"], "Visible rendering state differs from the baseline"
    assert before["ranges"] == 40 and before["values"] == 40
    print("PASS: before/after rendering states match, marker writes reduced from 80 to 2")
