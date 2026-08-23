"""Parse a markdown story file into pages.

Pages are split on lines containing only '---'. A page may start with
'@specimen <id>' to pin a specimen. Inline images '![alt](path)' are
collected so the CLI can copy them into the bundle.
"""
from __future__ import annotations

import re

_IMG_RE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")


def parse_story(md: str) -> tuple[list[dict], list[str]]:
    pages: list[dict] = []
    images: list[str] = []
    for chunk in re.split(r"^---\s*$", md, flags=re.MULTILINE):
        text = chunk.strip()
        if not text:
            continue
        specimen = None
        lines = text.splitlines()
        if lines and lines[0].startswith("@specimen "):
            specimen = lines[0].removeprefix("@specimen ").strip()
            text = "\n".join(lines[1:]).strip()
        images.extend(m for m in _IMG_RE.findall(text) if m not in images)
        pages.append({"text": text, "specimen": specimen})
    return pages, images
