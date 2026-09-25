#!/usr/bin/env python3
"""Resolve git conflict hunks by keeping both sides (ours, then theirs). For append-style docs only."""
import re, sys
for path in sys.argv[1:]:
    text = open(path, encoding='utf-8').read()
    pattern = re.compile(r'<<<<<<< [^\n]*\n(.*?)(?:\|\|\|\|\|\|\| [^\n]*\n.*?)?=======\n(.*?)>>>>>>> [^\n]*\n', re.S)
    resolved, count = pattern.subn(lambda m: m.group(1) + m.group(2), text)
    if '<<<<<<<' in resolved or '>>>>>>>' in resolved:
        sys.exit(f'{path}: unresolved markers remain')
    open(path, 'w', encoding='utf-8').write(resolved)
    print(f'{path}: {count} hunk(s) resolved')
