#!/usr/bin/env python3
"""
从「预览」窗口标题解析当前页（与 hammerspoon/yulan_pdf_export.lua 中
extractPageFromTitleLikeString 保持同一套规则）。
stdin: 一行 JSON，形如 {"path": "...", "title": "..."}
stdout: 两行 — 第一行 path，第二行页码数字或空行（表示未能从标题解析）。
"""
import json
import re
import sys
from typing import Optional


def page_from_title(title: str) -> Optional[int]:
    if not title:
        return None
    tl = title.lower()
    patterns: list[tuple[str, str]] = [
        (title, r"页码\s*[:：∶]\s*(\d+)\s*[/／]\s*\d+"),
        (title, r"[页頁]\s*[码碼]\s*[:：∶]\s*(\d+)\s*[/／]\s*\d+"),
        (title, r"页码\s*(\d+)\s*[/／]\s*\d+"),
        (title, r"页码[^\d]*(\d+)\s*[/／]\s*\d+"),
        (tl, r"page\s+(\d+)\s+of\s+\d+"),
        (tl, r"[–—\-]\s*page\s+(\d+)\s+of\s+\d+"),
    ]
    for s, pat in patterns:
        m = re.search(pat, s)
        if m:
            return int(m.group(1))
    return None


def main() -> None:
    raw = sys.stdin.read()
    data = json.loads(raw)
    path = data.get("path") or ""
    title = data.get("title") or ""
    page = page_from_title(title)
    sys.stdout.write(path + "\n")
    sys.stdout.write((str(page) if page is not None else "") + "\n")


if __name__ == "__main__":
    main()
