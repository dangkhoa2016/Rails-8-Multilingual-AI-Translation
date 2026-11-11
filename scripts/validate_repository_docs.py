#!/usr/bin/env python3
"""Validate bilingual Markdown pairs, language switches, links, license and community files.

Uses only the Python standard library; safe for CPU-only CI.
"""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
errors = []
markdown = sorted(ROOT.rglob("*.md"))
markdown = [p for p in markdown if not any(x in {".git", "tmp", "log", "vendor", "node_modules"} for x in p.relative_to(ROOT).parts)]
links = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
required = [
    ".github/CODEOWNERS",
    ".github/CODE_OF_CONDUCT.md",
    ".github/CODE_OF_CONDUCT.vi.md",
    ".github/CONTRIBUTING.md",
    ".github/CONTRIBUTING.vi.md",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/PULL_REQUEST_TEMPLATE.vi.md",
    ".github/SECURITY.md",
    ".github/SECURITY.vi.md",
    ".github/SUPPORT.md",
    ".github/SUPPORT.vi.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/feature_request.yml",
    ".github/ISSUE_TEMPLATE/question.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/dependabot.yml",
    ".github/workflows/ci.yml",
    "README.md",
    "README.vi.md",
    "CHANGELOG.md",
    "CHANGELOG.vi.md",
    "LICENSE",
]
for name in required:
    if not (ROOT / name).is_file():
        errors.append(f"Missing repository file: {name}")

for path in markdown:
    relative = path.relative_to(ROOT)
    name = path.name
    is_vi = name.endswith(".vi.md")
    partner_name = name[:-6] + ".md" if is_vi else path.stem + ".vi.md"
    partner = path.with_name(partner_name)
    text = path.read_text(encoding="utf-8")
    if not partner.is_file():
        errors.append(f"{relative}: missing language pair {partner_name}")
    if "Language / Ngôn ngữ:" not in text[:1600] or f"({partner_name})" not in text[:1600]:
        errors.append(f"{relative}: missing reciprocal language switch")
    if not text.startswith("# "):
        errors.append(f"{relative}: no document title")

    for match in links.finditer(text):
        raw = match.group(1).strip().split()[0].strip("<>")
        if not raw or raw.startswith(("#", "http:", "https:", "mailto:", "tel:", "data:")):
            continue
        local = unquote(raw.split("#")[0].split("?")[0])
        candidate = (path.parent / local).resolve()
        if not candidate.is_relative_to(ROOT.resolve()):
            errors.append(f"{relative}: escaping link {raw}")
        elif not candidate.exists():
            errors.append(f"{relative}: broken relative link {raw}")

license_text = (ROOT / "LICENSE").read_text(encoding="utf-8") if (ROOT / "LICENSE").exists() else ""
for value in ("MIT License", "Copyright (c) 2026 Đăng Khoa <i.am@dangkhoa.dev>"):
    if value not in license_text:
        errors.append(f"LICENSE: missing {value!r}")

for name in ("README.md", "README.vi.md"):
    p = ROOT / name
    if p.is_file():
        s = p.read_text(encoding="utf-8")
        for word in ("CI", "Rails", "Ruby", "PostgreSQL", "MIT", "Devise", "Pundit"):
            if word not in s[:1800]:
                errors.append(f"{name}: missing header badge mentioning {word}")

if errors:
    for message in errors:
        print("[FAIL]", message, file=sys.stderr)
    print(f"Bilingual documentation audit: {len(errors)} failures", file=sys.stderr)
    sys.exit(1)

print(f"[PASS] BILINGUAL_DOCUMENTATION_PAIRS={len(markdown)//2}")
print("[PASS] RELATIVE_LINKS_VALID")
print("[PASS] GITHUB_COMMUNITY_METADATA")
print("[PASS] MIT_LICENSE_ATTRIBUTION")
print("[PASS] README_BADGES_VALID")
