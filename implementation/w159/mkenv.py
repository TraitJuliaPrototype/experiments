#!/usr/bin/env python3
"""W-159: an environment of a harness, made for one setting of the round.

    mkenv.py <source env dir> <target env dir> <from>=<to> ...

Copies Project.toml and Manifest.toml. Every `path = "..."` (the manifest's entries and the project's
[sources]) is read relative to the source environment, made absolute, and its tree replaced by the
setting's: a pair <from>=<to> replaces the path <from> or a path below it (whole components only, the
longest <from> first). A path that does not exist after the replacement is an error: the setting lacks a tree.
The manifest's dependency lists are kept: the trees of the head and of the tag declare the same dependencies
(their Project.toml differ only in the paths of [sources]), so one manifest serves both.
"""
import os, re, sys

src, dst = sys.argv[1], sys.argv[2]
pairs = []
for a in sys.argv[3:]:
    f, t = a.split("=", 1)
    pairs.append((os.path.normpath(f), os.path.normpath(t)))
pairs.sort(key=lambda p: -len(p[0]))

missing = []

def remap(p):
    for f, t in pairs:
        if p == f or p.startswith(f + "/"):
            return t + p[len(f):]
    return p

def fix(m):
    p = m.group(2)
    p = os.path.normpath(p if os.path.isabs(p) else os.path.join(src, p))
    q = remap(p)
    if not os.path.isfile(os.path.join(q, "Project.toml")) and not os.path.isfile(os.path.join(q, "JuliaProject.toml")):
        missing.append(q)
    return m.group(1) + q + '"'

os.makedirs(dst, exist_ok=True)
for name in ("Project.toml", "Manifest.toml"):
    s = open(os.path.join(src, name)).read()
    s = re.sub(r'(path\s*=\s*")([^"]+)"', fix, s)
    open(os.path.join(dst, name), "w").write(s)
with open(os.path.join(dst, "ORIGIN"), "w") as o:
    o.write("made by w159/mkenv.py from %s\n" % os.path.abspath(src))
    for f, t in pairs:
        o.write("  %s -> %s\n" % (f, t))
if missing:
    sys.stderr.write("mkenv: MISSING TREE(S) for %s:\n  %s\n" % (dst, "\n  ".join(sorted(set(missing)))))
    sys.exit(1)
