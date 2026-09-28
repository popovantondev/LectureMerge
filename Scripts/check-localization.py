#!/usr/bin/env python3
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = ("ru", "de", "en")
CYRILLIC = re.compile(r"[А-Яа-яЁё]")
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:@|[diuf])")
ENTRY = re.compile(r'^\s*("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");\s*$')


def read_catalog(path):
    subprocess.run(["plutil", "-lint", str(path)], check=True, capture_output=True)
    result = {}
    for line_number, line in enumerate(path.read_text().splitlines(), start=1):
        if not line.strip() or line.lstrip().startswith("/*") or line.lstrip().startswith("//"):
            continue
        match = ENTRY.match(line)
        if not match:
            raise SystemExit(f"Invalid .strings entry at {path}:{line_number}")
        key, value = (json.loads(part) for part in match.groups())
        if key in result:
            raise SystemExit(f"Duplicate localization key {key!r} in {path}")
        result[key] = value
    return result


localizable = {}
info_plist = {}
for language in LANGUAGES:
    folder = ROOT / "Resources" / f"{language}.lproj"
    localizable[language] = read_catalog(folder / "Localizable.strings")
    info_plist[language] = read_catalog(folder / "InfoPlist.strings")

for name, catalogs in (("Localizable.strings", localizable), ("InfoPlist.strings", info_plist)):
    baseline = set(catalogs["ru"])
    for language, catalog in catalogs.items():
        missing = baseline - set(catalog)
        extra = set(catalog) - baseline
        if missing or extra:
            raise SystemExit(f"{name} keys differ for {language}: missing={sorted(missing)}, extra={sorted(extra)}")

for key in localizable["ru"]:
    expected = sorted(PLACEHOLDER.findall(key))
    for language in LANGUAGES:
        actual = sorted(PLACEHOLDER.findall(localizable[language][key]))
        if actual != expected:
            raise SystemExit(f"Format placeholders differ for {language}: {key!r}")
        if language in {"de", "en"} and CYRILLIC.search(localizable[language][key]):
            raise SystemExit(f"Cyrillic text in {language} value for {key!r}")

# Every fixed Russian string used by the SwiftUI window must have all three translations.
source = (ROOT / "Sources" / "App.swift").read_text()
for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', source):
    raw = match.group(1)
    if r"\(" in raw or not CYRILLIC.search(raw):
        continue
    key = json.loads('"' + raw + '"')
    if key not in localizable["ru"]:
        raise SystemExit(f"Uncatalogued app string: {key!r}")

print("Localization catalogs, format placeholders, and fixed app strings: OK")
