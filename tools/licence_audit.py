"""Check that every file under game/assets/ has a row in game/assets/LICENCES.md.

    tools/run.sh python3 tools/licence_audit.py

A row covers a file when its path (in backticks, relative to game/assets/) is the file's own
path, or is a folder ending in `/` that contains it. It also checks that every row points at
something that exists, so a deleted asset can't leave a stale licence row behind.

Exit code 0 = every file covered and every row live, 1 = not.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / "game" / "assets"
REGISTER = ASSETS / "LICENCES.md"

# Godot bookkeeping and repo scaffolding, not assets.
IGNORED_SUFFIXES = {".import", ".uid"}
IGNORED_NAMES = {"LICENCES.md", ".gitkeep", ".gdignore"}

ROW = re.compile(r"^\|\s*`([^`]+)`\s*\|")


def declared_paths() -> list[str]:
    return [m.group(1) for line in REGISTER.read_text(encoding="utf-8").splitlines()
            if (m := ROW.match(line))]


def asset_files() -> list[str]:
    return sorted(
        p.relative_to(ASSETS).as_posix()
        for p in ASSETS.rglob("*")
        if p.is_file() and p.suffix not in IGNORED_SUFFIXES and p.name not in IGNORED_NAMES
    )


def main() -> int:
    rows = declared_paths()
    uncovered = [f for f in asset_files()
                 if not any(f == r or (r.endswith("/") and f.startswith(r)) for r in rows)]
    stale = [r for r in rows if not (ASSETS / r).exists()]

    for f in uncovered:
        print(f"MISSING ROW  {f}")
    for r in stale:
        print(f"STALE ROW    {r}  (nothing at game/assets/{r})")
    ok = not uncovered and not stale
    print(f"licence audit: {len(asset_files())} file(s), {len(rows)} row(s): {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
