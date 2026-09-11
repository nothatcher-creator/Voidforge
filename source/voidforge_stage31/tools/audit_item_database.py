#!/usr/bin/env python3
"""Source-tree audit for VOIDFORGE production item resources.

Runtime discovery is manifest-driven, but this source audit intentionally scans the data
folder so an item file cannot be silently forgotten from the catalog.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ITEM_ROOT = ROOT / "data/items"
CATALOG = ITEM_ROOT / "item_catalog.tres"
VALID_ID = re.compile(r"^[a-z][a-z0-9_]*$")
FIELD_PATTERNS = {
    "id": re.compile(r'^id\s*=\s*&"([^"]+)"$', re.MULTILINE),
    "display_name": re.compile(r'^display_name\s*=\s*"([^"]*)"$', re.MULTILINE),
    "category": re.compile(r'^category\s*=\s*&"([^"]+)"$', re.MULTILINE),
    "mass": re.compile(r'^unit_mass_kg\s*=\s*([-+0-9.eE]+)$', re.MULTILINE),
    "volume": re.compile(r'^unit_volume_l\s*=\s*([-+0-9.eE]+)$', re.MULTILINE),
    "stack": re.compile(r'^stack_limit\s*=\s*([0-9]+)$', re.MULTILINE),
}
TAG_LINE = re.compile(r'^tags\s*=\s*Array\[StringName\]\(\[(.*)\]\)$', re.MULTILINE)
TAG_VALUE = re.compile(r'&"([^"]*)"')
CATALOG_PATH = re.compile(r'path="res://data/items/([^"]+\.tres)"')


def fail(errors: list[str]) -> int:
    for error in errors:
        print(f"ERROR: {error}")
    return 1


def main() -> int:
    errors: list[str] = []
    if not CATALOG.exists():
        return fail(["Missing data/items/item_catalog.tres"])

    item_files = sorted(p for p in ITEM_ROOT.rglob("*.tres") if p != CATALOG)
    if not item_files:
        return fail(["No production item definitions found."])

    ids: dict[str, Path] = {}
    categories: dict[str, int] = {}
    tag_counts: dict[str, int] = {}

    for path in item_files:
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        if 'path="res://scripts/inventory/item_definition.gd"' not in text:
            errors.append(f"{rel}: does not reference ItemDefinition script")
            continue

        parsed: dict[str, str] = {}
        for field, pattern in FIELD_PATTERNS.items():
            match = pattern.search(text)
            if not match:
                errors.append(f"{rel}: missing {field}")
            else:
                parsed[field] = match.group(1)
        if "id" not in parsed:
            continue

        item_id = parsed["id"]
        if not VALID_ID.fullmatch(item_id):
            errors.append(f"{rel}: invalid lowercase snake_case ID '{item_id}'")
        if item_id in ids:
            errors.append(f"Duplicate item ID '{item_id}': {ids[item_id].relative_to(ROOT)} and {rel}")
        else:
            ids[item_id] = path

        display_name = parsed.get("display_name", "")
        if not display_name.strip():
            errors.append(f"{rel}: display_name is empty")

        category = parsed.get("category", "")
        if category:
            if not VALID_ID.fullmatch(category):
                errors.append(f"{rel}: invalid category '{category}'")
            categories[category] = categories.get(category, 0) + 1

        try:
            if float(parsed.get("mass", "-1")) < 0:
                errors.append(f"{rel}: negative unit mass")
            if float(parsed.get("volume", "-1")) < 0:
                errors.append(f"{rel}: negative unit volume")
            if int(parsed.get("stack", "0")) <= 0:
                errors.append(f"{rel}: stack_limit must be positive")
        except ValueError:
            errors.append(f"{rel}: invalid numeric inventory field")

        tag_match = TAG_LINE.search(text)
        if not tag_match:
            errors.append(f"{rel}: missing tags array")
        else:
            tags = TAG_VALUE.findall(tag_match.group(1))
            if len(tags) != len(set(tags)):
                errors.append(f"{rel}: duplicate tags")
            for tag in tags:
                if not VALID_ID.fullmatch(tag):
                    errors.append(f"{rel}: invalid tag '{tag}'")
                tag_counts[tag] = tag_counts.get(tag, 0) + 1

    catalog_text = CATALOG.read_text(encoding="utf-8")
    catalog_refs = CATALOG_PATH.findall(catalog_text)
    expected_refs = sorted(str(p.relative_to(ITEM_ROOT)).replace("\\", "/") for p in item_files)
    actual_refs = sorted(catalog_refs)
    if len(catalog_refs) != len(set(catalog_refs)):
        errors.append("item_catalog.tres contains duplicate resource paths")
    missing = sorted(set(expected_refs) - set(actual_refs))
    extra = sorted(set(actual_refs) - set(expected_refs))
    if missing:
        errors.append("Catalog is missing item files: " + ", ".join(missing))
    if extra:
        errors.append("Catalog references unknown item files: " + ", ".join(extra))

    if errors:
        return fail(errors)

    print("VOIDFORGE item database source audit: PASS")
    print(f"Production items: {len(item_files)}")
    print("Categories: " + ", ".join(f"{key}={categories[key]}" for key in sorted(categories)))
    print(f"Unique tags: {len(tag_counts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
