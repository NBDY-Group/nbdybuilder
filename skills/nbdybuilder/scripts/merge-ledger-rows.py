#!/usr/bin/env python3
"""Resolve git conflict hunks in a markdown ledger table row by row.

For each row ID present on both sides, keep the row whose state is further along
(proposed < ready < in_progress < implemented < verified < done; `blocked` ranks
lowest so an unblock wins) and append any bold-dated notes (`**2026-..**: ...`)
that only the other side has. Rows present on one side only are kept.
Every other line in a hunk is kept verbatim, ours then theirs, without
de-duplication.

Usage: merge-ledger-rows.py <file> [<file> ...]
"""
import re
import sys

RANK = {"blocked": 0, "proposed": 1, "ready": 2, "in_progress": 3, "implemented": 4, "verified": 5, "done": 6}
HUNK = re.compile(r"<<<<<<< [^\n]*\n(.*?)(?:\|\|\|\|\|\|\| [^\n]*\n.*?)?=======\n(.*?)>>>>>>> [^\n]*\n", re.S)
ROW_ID = re.compile(r"^\| \*\*([^*]+)\*\* \|")
STATE = re.compile(r"\| `([a-z_]+)` \|")
NOTE = re.compile(r"\*\*[^*]*20\d\d-\d\d-\d\d[^*]*\*\*:?.*?(?=\s\*\*[^*]*20\d\d-\d\d-\d\d|\s\|\s*$)")


def notes(row: str) -> list[str]:
    return [m.group(0).strip() for m in NOTE.finditer(row)]


def merge_rows(ours: str, theirs: str) -> str:
    rank_o = RANK.get((STATE.search(ours) or [None, ""])[1], -1)
    rank_t = RANK.get((STATE.search(theirs) or [None, ""])[1], -1)
    base, other = (ours, theirs) if rank_o >= rank_t else (theirs, ours)
    extra = [n for n in notes(other) if n not in base]
    if not extra:
        return base
    return base.rstrip().removesuffix("|").rstrip() + " " + " ".join(extra) + " |"


def resolve(match: re.Match) -> str:
    ours_lines = match.group(1).rstrip("\n").split("\n")
    theirs_lines = match.group(2).rstrip("\n").split("\n")
    theirs_rows = {ROW_ID.match(l).group(1): l for l in theirs_lines if ROW_ID.match(l)}
    out, used = [], set()
    for line in ours_lines:
        m = ROW_ID.match(line)
        if m and m.group(1) in theirs_rows:
            out.append(merge_rows(line, theirs_rows[m.group(1)]))
            used.add(m.group(1))
        else:
            out.append(line)
    for line in theirs_lines:
        m = ROW_ID.match(line)
        if m and m.group(1) in used:
            continue
        out.append(line)
    return "\n".join(out) + "\n"


for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    resolved, count = HUNK.subn(resolve, text)
    if "<<<<<<<" in resolved or ">>>>>>>" in resolved:
        sys.exit(f"{path}: unresolved markers remain")
    open(path, "w", encoding="utf-8").write(resolved)
    print(f"{path}: {count} hunk(s) resolved")
