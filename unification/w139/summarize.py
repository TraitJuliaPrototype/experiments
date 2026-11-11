#!/usr/bin/env python3
"""E-361: summarize the trim verifier's report in a build log.
usage: summarize.py <log>...   Counts errors and warnings; groups them by the module of the frame the
unresolved call is in ([1]) and by the outermost frame (the root: where the program reaches it)."""
import re, sys, collections
for path in sys.argv[1:]:
    kind = None; frames = []; items = []
    def flush():
        if kind and frames: items.append((kind, frames[0], frames[-1]))
    for line in open(path, errors='replace'):
        m = re.match(r'^(Error|Warning) #\d+:', line)
        if m:
            flush(); kind = m.group(1); frames = []; cur = None; continue
        m = re.match(r'^\s*\[(\d+)\] (.*)$', line)
        if m and kind: cur = m.group(2)[:70]; continue
        m = re.match(r'^\s*@ (\S+)', line)
        if m and kind and cur is not None: frames.append((m.group(1), cur)); cur = None
    flush()
    ne = sum(1 for k, _, _ in items if k == 'Error'); nw = len(items) - ne
    tail = [l.strip() for l in open(path, errors='replace') if l.startswith(('object:', 'link:', 'verify_main', 'Trim verify'))]
    print(f"{path}: {ne} errors, {nw} warnings | " + ' | '.join(tail))
    for title, idx in (("in module", 1), ("reached from", 2)):
        c = collections.Counter((k, it[idx][0]) for it in items for k in [it[0]])
        print(f"  {title}: " + ', '.join(f"{m} {k[0]}{n}" for (k, m), n in c.most_common(12)))
    c = collections.Counter(it[2][0] + ' ' + it[2][1] for it in items)
    for r, n in c.most_common(int(__import__('os').environ.get('ROOTS', '6'))): print(f"    root {n:4d}  {r}")
