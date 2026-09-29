#!/usr/bin/env python3
"""Validate the Apple-Bug-Bounty-Skill knowledge base.

Checks that every skill module is loadable, that all cross-references and
supporting references resolve, and that the router/README tables match the files
on disk. Also guards this PUBLIC repo against accidental leaks (local absolute
paths, device UDIDs, embargoed case ids).

Usage:
    python3 scripts/validate_skills.py [--verbose] [--root DIR]

Exit status: 0 = all checks passed, 1 = at least one error.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

REQUIRED_KEYS = [
    "name",
    "description",
    "version",
    "agent_compatibility",
    "token_budget",
    "covers",
    "platforms",
    "triggers",
    "related_skills",
]

# Files allowed to differ from the skill-module conventions.
NON_SKILL_MD = {"README.md", "SKILL.md", "LICENSE", "GEMINI.md", ".codex.md"}

LEAK_PATTERNS = [
    (re.compile(r"/home/[a-z0-9_]+/"), "absolute home path"),
    (re.compile(r"~/Desktop/"), "absolute Desktop path"),
    (re.compile(r"\b[0-9A-F]{8}-[0-9A-F]{16}\b"), "device UDID"),
    (re.compile(r"sk-[A-Za-z0-9]{16,}"), "api key"),
]

# Advisory ids are fine to warn about but must not fail CI: the audit ids
# (BB-001..BB-031) are published in docs/researchdeepseek.md on purpose. New
# bounty case ids must be reviewed by hand before they land.
ADVISORY_PATTERNS = [
    (re.compile(r"\bBB-\d{3}\b"), "case id (confirm it is a published audit id, not an embargoed report)"),
]

# Generated / vendored trees that are not knowledge-base content.
SKIP_DIRS = {".git", ".opencode", ".hermes", "node_modules", "projects", "__pycache__"}

SKILL_REF = re.compile(r"skills/([a-z0-9-]+)\.md")
REF_PATH = re.compile(r"skills/references/([a-z0-9-]+)/([A-Za-z0-9._-]+)")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def parse_frontmatter(text: str) -> tuple[dict, str] | tuple[None, str]:
    if not text.startswith("---"):
        return None, text
    parts = text.split("\n---", 1)
    if len(parts) != 2:
        return None, text
    raw = parts[0][3:]
    body = parts[1]
    data: dict = {}
    current: str | None = None
    for line in raw.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("  - ") and current:
            data.setdefault(current, [])
            if isinstance(data[current], list):
                data[current].append(line.strip()[2:].strip().strip('"'))
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            current = key
            if val:
                data[key] = val.strip('"')
            else:
                data[key] = []
    return data, body


def skill_bodies(root: str) -> dict[str, str]:
    """path -> body (frontmatter stripped) for every markdown doc that states rules."""
    out: dict[str, str] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            p = os.path.join(dirpath, fn)
            text = open(p, encoding="utf-8", errors="replace").read()
            _fm, body = parse_frontmatter(text)
            out[os.path.relpath(p, root)] = body
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    rep = Report()

    skills_dir = os.path.join(root, "skills")
    if not os.path.isdir(skills_dir):
        print(f"FATAL: {skills_dir} not found", file=sys.stderr)
        return 1

    # ---- 1. skill modules -------------------------------------------------
    modules: dict[str, str] = {}
    for fn in sorted(os.listdir(skills_dir)):
        if not fn.endswith(".md") or fn in NON_SKILL_MD:
            continue
        name = fn[:-3]
        path = os.path.join(skills_dir, fn)
        text = open(path, encoding="utf-8", errors="replace").read()
        fm, body = parse_frontmatter(text)
        if fm is None:
            rep.error(f"skills/{fn}: missing or unterminated YAML frontmatter")
            continue
        for key in REQUIRED_KEYS:
            if key not in fm:
                rep.error(f"skills/{fn}: frontmatter missing required key '{key}'")
        if fm.get("name") != name:
            rep.error(f"skills/{fn}: frontmatter name '{fm.get('name')}' != filename '{name}'")
        desc = str(fm.get("description", ""))
        if not desc.startswith("Use "):
            rep.error(f"skills/{fn}: description must start with 'Use ' (got {desc[:40]!r})")
        for rel in fm.get("related_skills", []) or []:
            if not os.path.isfile(os.path.join(skills_dir, f"{rel}.md")):
                rep.error(f"skills/{fn}: related_skills entry '{rel}' has no skills/{rel}.md")
        refs = fm.get("references", []) or []
        for ref in refs:
            if not os.path.isfile(os.path.join(root, ref)):
                rep.error(f"skills/{fn}: references entry '{ref}' does not exist")
        if refs and not (fm.get("covers") and fm.get("triggers")):
            rep.warn(f"skills/{fn}: has references but thin covers/triggers")
        est = max(1, len(body) // 4)
        try:
            declared = int(str(fm.get("token_budget", 0)))
        except ValueError:
            declared = 0
            rep.error(f"skills/{fn}: token_budget is not an integer")
        if declared and est > declared * 1.7:
            rep.warn(f"skills/{fn}: body is ~{est} tokens, token_budget declares {declared}")
        if "research_first" not in fm:
            rep.error(f"skills/{fn}: missing research_first flag")
        modules[name] = path

    if not modules:
        rep.error("no skill modules found")
    print(f"skill modules: {len(modules)}")

    # ---- 2. reference trees ----------------------------------------------
    ref_root = os.path.join(skills_dir, "references")
    on_disk: dict[str, set[str]] = {}
    if os.path.isdir(ref_root):
        for name in sorted(os.listdir(ref_root)):
            d = os.path.join(ref_root, name)
            if not os.path.isdir(d):
                continue
            on_disk[name] = {f for f in os.listdir(d) if not f.startswith(".")}
            if name not in modules:
                rep.error(f"skills/references/{name}/ has no matching skills/{name}.md")
    declared_refs: dict[str, set[str]] = {}
    for name in modules:
        text = open(modules[name], encoding="utf-8", errors="replace").read()
        fm, _ = parse_frontmatter(text)
        fam = set()
        for ref in (fm or {}).get("references", []) or []:
            m = REF_PATH.search(str(ref))
            if m:
                fam.add(m.group(2))
        declared_refs[name] = fam
    for name, fam in declared_refs.items():
        disk = on_disk.get(name, set())
        for f in sorted(fam - disk):
            rep.error(f"skills/{name}: declares reference '{f}' not present on disk")
        for f in sorted(disk - fam):
            rep.error(f"skills/{name}: reference file '{f}' exists but is not declared in frontmatter")
    print(f"reference trees: {len(on_disk)}")

    # ---- 3. cross-file links resolve --------------------------------------
    bodies = skill_bodies(root)
    targets = set(modules)
    for rel, body in bodies.items():
        if rel.startswith("skills/references/"):
            continue
        for target in set(SKILL_REF.findall(body)):
            if target not in targets:
                rep.error(f"{rel}: links skills/{target}.md which does not exist")
    # router + README must cover every module
    for rel in ("SKILL.md", "README.md"):
        p = os.path.join(root, rel)
        if not os.path.isfile(p):
            rep.error(f"{rel} missing")
            continue
        text = open(p, encoding="utf-8", errors="replace").read()
        for name in sorted(targets):
            if name not in text:
                rep.warn(f"{rel}: does not mention skill module '{name}'")
    # options referenced by the router exist
    router = os.path.join(root, "SKILL.md")
    if os.path.isfile(router):
        rtext = open(router, encoding="utf-8", errors="replace").read()
        for opt in sorted(set(re.findall(r"options/([a-z-]+)\.md", rtext))):
            if not os.path.isfile(os.path.join(root, "options", f"{opt}.md")):
                rep.error(f"SKILL.md: references options/{opt}.md which does not exist")
        for skill in sorted(set(re.findall(r"skills/references/([a-z0-9-]+)/", rtext))):
            if skill not in on_disk:
                rep.error(f"SKILL.md: references skills/references/{skill}/ which does not exist")

    # ---- 4. installer / uninstaller drift ---------------------------------
    # A module added to skills/ but not to the installers is invisible to users;
    # a module added to setup but not to the uninstaller leaves dangling links.
    module_names = set(modules)
    for rel in ("setup", "setup.ps1"):
        p = os.path.join(root, rel)
        if not os.path.isfile(p):
            rep.error(f"{rel} missing")
            continue
        text = open(p, encoding="utf-8", errors="replace").read().replace("\\", "/")
        listed = set(re.findall(r"skills/([a-z0-9-]+)\.md", text))
        for name in sorted(module_names - listed):
            rep.error(
                f"{rel}: skill module '{name}' is not registered — add it to SKILL_MAP "
                f"and the required-files list, or users never get it"
            )
        for name in sorted(listed - module_names):
            rep.error(f"{rel}: references skills/{name}.md which does not exist")
    for rel in ("uninstall", "uninstall.ps1"):
        p = os.path.join(root, rel)
        if not os.path.isfile(p):
            rep.error(f"{rel} missing")
            continue
        text = open(p, encoding="utf-8", errors="replace").read()
        for name in sorted(module_names & set(re.findall(r"\b([a-z0-9-]+)\b", text))):
            if re.search(rf'["\']{re.escape(name)}["\']', text):
                rep.error(
                    f"{rel}: hardcodes the module name '{name}' — clean up by link target "
                    f"instead, a name list drifts and leaves dangling links behind"
                )

    # ---- 5. public-repo leak guard ---------------------------------------
    for rel, body in bodies.items():
        if rel.startswith("projects/"):
            continue  # vendored third-party trees
        for lineno, line in enumerate(body.splitlines(), 1):
            for pat, label in LEAK_PATTERNS:
                if pat.search(line):
                    rep.error(f"{rel}:{lineno}: possible leak — {label}: {line.strip()[:90]}")
            for pat, label in ADVISORY_PATTERNS:
                if pat.search(line):
                    rep.warn(f"{rel}:{lineno}: {label}: {line.strip()[:70]}")
    # also scan skill frontmatter
    for name, path in modules.items():
        text = open(path, encoding="utf-8", errors="replace").read()
        fm, _ = parse_frontmatter(text)
        blob = " ".join(f"{k}:{v}" for k, v in (fm or {}).items() if isinstance(v, str))
        for pat, label in LEAK_PATTERNS:
            if pat.search(blob):
                rep.error(f"skills/{name}.md: frontmatter leak — {label}")

    print(f"docs scanned: {len(bodies)}")

    # ---- report ----------------------------------------------------------
    if args.verbose:
        for w in rep.warnings:
            print(f"warn: {w}")
    else:
        for w in rep.warnings[:10]:
            print(f"warn: {w}")
        if len(rep.warnings) > 10:
            print(f"warn: … {len(rep.warnings) - 10} more (rerun with --verbose)")
    for e in rep.errors:
        print(f"ERROR: {e}")
    print(f"\n{len(rep.errors)} error(s), {len(rep.warnings)} warning(s)")
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
