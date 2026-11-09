#!/usr/bin/env python3
"""Link, anchor and section-citation checker for writeup/.

Usage: python3 -I check_links.py <writeup-dir> [--all]

Adopted from the documentation review of 2026-11-09 (writeup/reviews/2026-11-09-documentation-consistency.md);
a citation that is a link's text is checked against the linked file (an attic reference keeps its numbering).

Checks, for every current document (history dirs skipped unless --all):
  1. markdown links [t](path#anchor): the file exists; the anchor matches a
     heading slug (GitHub style) or an explicit <a id="..."> in the target;
  2. prose citations "traits §7.5", "compiler §4.8", "facts §10", "lowering §3"
     and bare "§x.y" inside a reference: a heading numbered so exists.
Prints one line per problem: file:line: kind: detail.
"""
import os, re, sys

HISTORY = {"reviews", "plans", "attic", "session-notes", "explorations", "reference-unified"}
REF = {"traits": "reference/traits.md", "facts": "reference/facts.md",
       "compiler": "reference/compiler.md", "lowering": "reference/lowering.md"}

def slug(h):
    h = h.strip().lower()
    h = re.sub(r"`", "", h)
    h = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", h)
    h = re.sub(r"[^\w\- ]", "", h)
    h = h.replace(" ", "-")
    return h

def headings(path, cache={}):
    if path in cache:
        return cache[path]
    anchors, numbered = set(), set()
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = re.match(r"^(#{1,6})\s+(.*)$", line)
                if m:
                    text = m.group(2)
                    s = slug(text)
                    if s in anchors:   # github dedup: -1, -2 ...
                        i = 1
                        while f"{s}-{i}" in anchors: i += 1
                        s = f"{s}-{i}"
                    anchors.add(s)
                    n = re.match(r"^(\d+[a-z]?(?:\.\d+)*)\.?\s", text)
                    if n: numbered.add(n.group(1))
                for a in re.findall(r'<a id="([^"]+)"', line):
                    anchors.add(a)
    except OSError:
        pass
    cache[path] = (anchors, numbered)
    return cache[path]

def link_target(line, s, e, path):
    """The file a markdown link points at when [s, e) lies in its text, else None."""
    o = line.rfind("[", 0, s)
    if o < 0 or "]" in line[o:s]: return None
    m = re.match(r"[^\]]*\]\(([^)\s#]*)", line[e:])
    if not m: return None
    p = m.group(1)
    return path if p == "" else os.path.normpath(os.path.join(os.path.dirname(path), p))

def main():
    root = os.path.abspath(sys.argv[1]); allf = "--all" in sys.argv
    files = []
    for d, dirs, fs in os.walk(root):
        rel = os.path.relpath(d, root)
        top = rel.split(os.sep)[0]
        if not allf and top in HISTORY: 
            dirs[:] = []; continue
        for f in fs:
            if f.endswith(".md"): files.append(os.path.join(d, f))
    nprob = 0
    for path in sorted(files):
        rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
        for i, line in enumerate(lines, 1):
            for m in re.finditer(r"\]\(([^)\s]+)\)", line):
                tgt = m.group(1)
                if re.match(r"^[a-z]+://", tgt) or tgt.startswith("mailto:"): continue
                p, _, anc = tgt.partition("#")
                tpath = path if p == "" else os.path.normpath(os.path.join(os.path.dirname(path), p))
                if p and not os.path.exists(tpath):
                    print(f"{rel}:{i}: missing-file: {tgt}"); nprob += 1; continue
                if anc and tpath.endswith(".md"):
                    anchors, _ = headings(tpath)
                    if anc not in anchors:
                        print(f"{rel}:{i}: missing-anchor: {tgt}"); nprob += 1
            # prose citations
            for m in re.finditer(r"\b(traits|facts|compiler|lowering)(?:\.md)?(?:'s)?\s+§(\d+[a-z]?(?:\.\d+)*)", line):
                ref, sec = m.group(1), m.group(2)
                tpath = os.path.join(root, REF[ref])
                lt = link_target(line, m.start(), m.end(), path)
                if lt is not None:          # a citation that is a link's text: checked against the link's file
                    if not lt.endswith(".md") or os.path.basename(lt)[:-3] not in REF: continue
                    tpath = lt
                _, numbered = headings(tpath)
                if sec not in numbered:
                    print(f"{rel}:{i}: missing-section: {ref} §{sec}"); nprob += 1
            if rel.startswith("reference/") and os.path.basename(rel)[:-3] in REF:
                for m in re.finditer(r"(?<![\w§])§(\d+[a-z]?(?:\.\d+)*)", line):
                    # skip when preceded by a reference name (handled above)
                    pre = line[max(0, m.start()-12):m.start()]
                    if re.search(r"(traits|facts|compiler|lowering)(?:\.md)?(?:'s)?\s+§[\d.]+(?:, §[\d.]+)*,? (?:and )?$", line[max(0, m.start()-40):m.start()]): continue
                    if re.search(r"(traits|facts|compiler|lowering)(?:\.md)?(?:'s)?\s+$", pre): continue
                    if re.search(r"(issues?|decisions|evidence|state|todo|INDEX|changes|design)(?:\.md)?\)?\s+$", pre): continue
                    lt = link_target(line, m.start(), m.end(), path)
                    if lt is not None and os.path.normpath(lt) != os.path.normpath(path): continue
                    _, numbered = headings(path)
                    if m.group(1) not in numbered:
                        print(f"{rel}:{i}: missing-own-section: §{m.group(1)}"); nprob += 1
    print(f"-- {nprob} problems in {len(files)} files", file=sys.stderr)

main()
