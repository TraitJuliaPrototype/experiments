#!/usr/bin/env python3
"""Check that every link with an anchor, between the current documents, lands on a heading or an <a id>.

    python3 experiments/tools/doclint/anchors.py            # from the workspace root

It reads the documents doclint.py reads (the current ones: not the attic, the session notes, plans or reviews),
and prints one line per link whose target file exists and has no such anchor. Exit status 1 if any.
"""
import os, re, sys, glob
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
def slug(h):
    h = re.sub(r"<[^>]+>", "", h)
    h = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", h)
    s = h.strip().lower()
    s = re.sub(r"[^\w\- ]", "", s, flags=re.U)
    return s.replace(" ", "-")
cache = {}
def anchors(path):
    if path not in cache:
        t = open(path, encoding="utf-8").read()
        t = re.sub(r"```.*?```", "", t, flags=re.S)
        a = set(re.findall(r'<a id="([^"]+)"', t))
        seen = {}
        for h in re.findall(r"^#+ (.+)$", t, re.M):
            s = slug(h); n = seen.get(s, 0); seen[s] = n + 1
            a.add(s if n == 0 else f"{s}-{n}")
        cache[path] = a
    return cache[path]
docs = [p for p in glob.glob(os.path.join(ROOT, "writeup", "**", "*.md"), recursive=True)
        if not re.search(r"/(plans|reviews)/|record/(harvest|design-history|decisions|.*research|julia-1\.14)", p)]
docs += [os.path.join(ROOT, "README.md"), os.path.join(ROOT, "CLAUDE.md")]
bad = 0
for p in sorted(docs):
    t = open(p, encoding="utf-8").read()
    t = re.sub(r"```.*?```", "", t, flags=re.S)
    for target, anchor in re.findall(r"\]\(([^)\s#]*)#([^)\s]+)\)", t):
        if re.match(r"[a-z]+:", target):
            continue
        q = p if target == "" else os.path.normpath(os.path.join(os.path.dirname(p), target))
        if not (q.endswith(".md") and os.path.isfile(q)):
            continue
        if anchor not in anchors(q):
            bad += 1
            print(f"{os.path.relpath(p, ROOT)}: {target}#{anchor}")
print(f"{bad} links with a missing anchor")
sys.exit(1 if bad else 0)
