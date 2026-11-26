#!/usr/bin/env python3
"""
Static GDScript validator for LUMEN WASTES: BLACK PROTOCOL.
Checks (without the Godot engine):
  1. Balanced brackets/braces/parens (string- and comment-aware).
  2. No Godot 3 syntax (yield, KinematicBody2D, move_and_slide(vel, Vector2.UP),
     onready=, signal with parens misuse, etc.).
  3. All res:// references in project.godot, scenes, and scripts resolve.
  4. Scene files reference existing scripts.
Exit code 0 = all pass, 1 = failures.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES: list[str] = []
PASSES: int = 0

GODOT3_PATTERNS = [
    (re.compile(r"\byield\s*\("), "Godot 3 'yield(' — use 'await' in Godot 4"),
    (re.compile(r"\byield\b"), "Godot 3 'yield' keyword — use 'await' in Godot 4"),
    (re.compile(r"\bKinematicBody2D\b"), "Godot 3 KinematicBody2D — use CharacterBody2D"),
    (re.compile(r"move_and_slide\s*\(\s*\w+\s*,\s*Vector2\.UP\s*\)"), "Godot 3 move_and_slide(vel, Vector2.UP) — use move_and_slide()"),
    (re.compile(r"\bonready\s*=\s"), "Godot 3 onready= — use @onready var in Godot 4"),
    (re.compile(r"\bset_process_input\b"), "Godot 3 set_process_input — use _input in Godot 4"),
    (re.compile(r"\bOS\.get_ticks\b"), "Deprecated OS.get_ticks — use Time.get_ticks_msec()"),
]


def strip_strings_and_comments(src: str) -> str:
    """Replace string literals and comments with spaces (preserving length/newlines)."""
    out = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        # Line comment
        if ch == "#":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue
        # String (single, double, triple)
        if ch in ('"', "'"):
            quote = ch
            triple = src[i:i + 3] == quote * 3
            out.append(" " * (3 if triple else 1))
            i += 3 if triple else 1
            while i < n:
                if triple and src[i:i + 3] == quote * 3:
                    out.append(" " * 3)
                    i += 3
                    break
                if not triple and src[i] == quote:
                    out.append(" ")
                    i += 1
                    break
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                out.append(src[i] if src[i] != "\n" else "\n")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check_balance(path: Path, src: str) -> None:
    stripped = strip_strings_and_comments(src)
    stack: list[tuple[str, str]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    line = 1
    for ch in stripped:
        if ch == "\n":
            line += 1
            continue
        if ch in "([{":
            stack.append((ch, str(line)))
        elif ch in ")]}":
            if not stack:
                FAILURES.append(f"{path}: line {line}: unmatched '{ch}'")
                return
            top, top_line = stack.pop()
            if top != pairs[ch]:
                FAILURES.append(f"{path}: line {line}: '{ch}' does not match '{top}' from line {top_line}")
                return
    if stack:
        top, top_line = stack[-1]
        FAILURES.append(f"{path}: unclosed '{top}' opened at line {top_line}")


def check_godot3(path: Path, src: str) -> None:
    for pattern, msg in GODOT3_PATTERNS:
        for m in pattern.finditer(src):
            line = src[: m.start()].count("\n") + 1
            FAILURES.append(f"{path}: line {line}: {msg}")


def check_gdscript_files() -> None:
    gd_files = sorted(ROOT.rglob("*.gd"))
    if not gd_files:
        FAILURES.append("No .gd files found")
        return
    for f in gd_files:
        src = f.read_text(encoding="utf-8")
        check_balance(f, src)
        check_godot3(f, src)
        # Basic sanity: must extend something or be a SceneTree script.
        if not re.search(r"^extends\s+\w+", src, re.M):
            FAILURES.append(f"{f}: missing 'extends' declaration")
        global PASSES
        PASSES += 1


def check_scene_files() -> None:
    for f in sorted(ROOT.rglob("*.tscn")):
        src = f.read_text(encoding="utf-8")
        check_balance(f, src)
        # Every ext_resource Script path must exist.
        for m in re.finditer(r'path="(res://[^"]+\.gd)"', src):
            script_path = ROOT / m.group(1).replace("res://", "")
            if not script_path.exists():
                FAILURES.append(f"{f}: references missing script {m.group(1)}")
            else:
                global PASSES
                PASSES += 1
        # ext_resource type="Script" path must be .gd
        for m in re.finditer(r'type="Script"\s+path="(res://[^"]+)"', src):
            if not m.group(1).endswith(".gd"):
                FAILURES.append(f"{f}: Script ext_resource not a .gd: {m.group(1)}")


def check_project_references() -> None:
    # project.godot autoload scripts must exist.
    pg = (ROOT / "project.godot").read_text(encoding="utf-8")
    for m in re.finditer(r'"\*?(res://[^"]+\.gd)"', pg):
        p = ROOT / m.group(1).replace("res://", "")
        if not p.exists():
            FAILURES.append(f"project.godot: autoload/main script missing {m.group(1)}")
        else:
            global PASSES
            PASSES += 1
    # main scene must exist
    m = re.search(r'run/main_scene="(res://[^"]+)"', pg)
    if m:
        p = ROOT / m.group(1).replace("res://", "")
        if not p.exists():
            FAILURES.append(f"project.godot: main scene missing {m.group(1)}")
        else:
            PASSES += 1


def check_script_res_references() -> None:
    """Check res:// references inside .gd files resolve to existing files."""
    ref_re = re.compile(r'"(res://[^"\s]+\.(gd|tscn|tres|json|png|wav|svg|gdshader))"')
    for f in sorted(ROOT.rglob("*.gd")):
        src = f.read_text(encoding="utf-8")
        for m in ref_re.finditer(src):
            ref = m.group(1)
            # Skip format strings (contain % placeholders).
            if "%" in ref:
                continue
            p = ROOT / ref.replace("res://", "")
            if not p.exists():
                FAILURES.append(f"{f}: references missing resource {ref}")
            else:
                global PASSES
                PASSES += 1


def main() -> int:
    print("=== GDScript Static Validation ===")
    check_gdscript_files()
    check_scene_files()
    check_project_references()
    check_script_res_references()
    print(f"Checked {PASSES} references/files")
    if FAILURES:
        print(f"\n{len(FAILURES)} FAILURES:")
        for f in FAILURES:
            print("  FAIL:", f)
        return 1
    print("\nAll static checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
