#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


def normalize_tags(tags_raw: str, version: str) -> list[str]:
    tags = []
    for line in tags_raw.splitlines():
        line = line.strip()
        if not line:
            continue
        # Strip image prefix (repo:tag -> tag)
        tag = line.split(":")[-1]
        if tag.startswith("sha-"):
            continue
        if tag not in tags:
            tags.append(tag)
    # Prefer common tags in a stable order
    preferred = []
    for t in (version, "latest", "beta"):
        if t in tags:
            preferred.append(t)
    for t in tags:
        if t not in preferred:
            preferred.append(t)
    return preferred


def format_tags(tags: list[str]) -> str:
    return ", ".join(f"`{t}`" for t in tags)


def main() -> int:
    if len(sys.argv) < 5:
        print("usage: update-docs-changelog.py <date> <version> <sha> <tags>", file=sys.stderr)
        return 1

    date, version, sha, tags_raw = sys.argv[1:5]
    notes = sys.argv[5] if len(sys.argv) > 5 else ""
    tags = normalize_tags(tags_raw, version)
    if version not in tags:
        print(f"version tag {version} not found in tags; skipping changelog update")
        return 0
    tags_str = format_tags(tags)
    if not notes:
        notes = f"Automated build ({sha})."

    path = Path("docs/README.md")
    content = path.read_text()

    header = "| Date | Build Version | Docker Tags | Notes |"
    separator = "| --- | --- | --- | --- |"

    existing_rows = []
    in_table = False
    for line in content.splitlines():
        if line.strip() == header:
            in_table = True
            continue
        if in_table:
            if not line.startswith("|"):
                break
            if line.strip() == separator:
                continue
            existing_rows.append(line.strip())

    for row in existing_rows:
        if f"| {version} |" in row:
            return 0
        if row.startswith(f"| {date} |") and tags_str in row:
            return 0

    if version in content:
        return 0

    idx = content.find(header)
    if idx == -1:
        print("changelog table header not found", file=sys.stderr)
        return 1

    insert_pos = content.find(separator, idx)
    if insert_pos == -1:
        print("changelog table separator not found", file=sys.stderr)
        return 1

    insert_pos = content.find("\n", insert_pos)
    if insert_pos == -1:
        insert_pos = len(content)
    else:
        insert_pos += 1

    new_row = f"| {date} | {version} | {tags_str} | {notes} |\\n"
    updated = content[:insert_pos] + new_row + content[insert_pos:]
    path.write_text(updated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
