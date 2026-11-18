#!/usr/bin/env python3
"""doclint: count what the documentation rules forbid in the current documents.

Usage: doclint.py [WORKSPACE] [--details CHECK] [--file PATH]

WORKSPACE is the design repository's root (default: two levels above experiments/tools).
The rules are R1 to R4 of writeup/plans/2026-11-18-documentation-cleanup.md.
It reads files only. Python 3, standard library.
"""
import glob
import os
import re
import sys

# The current documents. "strict": every check. "design": strict, plus the checks for the references.
# "history": documents that are about the history by their purpose; only their links are checked.
STRICT = [
    "README.md", "writeup/README.md", "writeup/goals.md", "writeup/state.md", "writeup/design.md",
    "writeup/glossary.md", "writeup/setup.md", "writeup/open-issues.md", "writeup/intro/*.md",
    "writeup/design/evidence.md", "writeup/design/julia-changes.md", "writeup/design/other-languages.md",
    "writeup/design/proofs.md", "writeup/record/INDEX.md", "writeup/record/todo.md",
    "writeup/record/experiments.md",
]
REFERENCES = ["writeup/reference/*.md"]
HISTORY = [
    "writeup/design/alternatives.md", "writeup/design/lessons.md", "writeup/record/decisions.md",
    "writeup/record/design-history.md", "writeup/record/performance-explorations.md",
]
# Plans and reviews a current document may link to.
LIVE = [
    "plans/2026-11-15-next-iteration.md", "plans/2026-11-14-synthesis.md",
    "plans/2026-11-18-documentation-cleanup.md", "reviews/2026-11-15-conceptual-design.md",
]

CHECKS = {
    # R1: the unified line is the implementation.
    "earlier-build": re.compile(
        r"julia-1\.13|trait-world-1\.13|earlier build|earlier library|earlier prototype|previous build"
        r"|package prototype|TraitWorld `?main`?|unified build", re.I),
    # R2: no chronology.
    "history-words": re.compile(
        r"no longer|superseded|formerly|used to\b|Earlier:|\bWas:|\(was |replaced by|\bdecided\b|built on\b"
        r"|until 20\d\d|has been removed|were removed", re.I),
    "dates": re.compile(r"\b20\d\d-\d\d-\d\d\b"),
    # R3: a baseline is plain Julia or Python. A word list; every hit is read by hand.
    "iteration-compare": re.compile(
        r"against the baseline|the baseline's|the attribute's \d|prototype-2026-11|earlier build's"
        r"|on the baseline|than on the baseline|the prototype's \d", re.I),
    # R4: no link from a current document into what is archived or about to be.
    "links-to-archive": re.compile(r"\]\(([^)#\s]*(?:plans|reviews|explorations|attic)/[^)#\s]*)"),
}
REF_CHECKS = {
    "commits": re.compile(r"\b(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])[0-9a-f]{7,10}\b"),
    "work-items": re.compile(r"\bW-\d+\b"),
    "plan-rows": re.compile(r"\bD-\d+\b"),
    "branches": re.compile(r"`(?:unified|next|next-s3|s3|unified-w141)`|julia-(?:unified|next|s3)"),
    "the-users-words": re.compile(r"the user[ ,(]|\bmine\b"),
}
LINK = re.compile(r"\]\(([^)\s]+)\)")
EID = re.compile(r"\bE-(\d+)\b")


def expand(root, patterns):
    out = []
    for p in patterns:
        out.extend(sorted(glob.glob(os.path.join(root, p))))
    return [f for f in out if os.path.isfile(f)]


def registry_ids(root):
    """IDs that have a row in the current registry, and IDs in the archive if it exists."""
    cur, arch = set(), set()
    row = re.compile(r"^\|\s*E-(\d+)\b")
    for path, dest in (("writeup/record/experiments.md", cur),
                       ("attic/writeup/record/experiments-archive.md", arch)):
        full = os.path.join(root, path)
        if os.path.isfile(full):
            for line in open(full, encoding="utf-8"):
                m = row.match(line)
                if m:
                    dest.add(int(m.group(1)))
    return cur, arch


def broken_links(root, path, text):
    bad = []
    base = os.path.dirname(path)
    for target in LINK.findall(text):
        if re.match(r"[a-z]+:", target) or target.startswith("#"):
            continue
        rel = target.split("#")[0]
        if not rel:
            continue
        if not os.path.exists(os.path.normpath(os.path.join(base, rel))):
            bad.append(target)
    return bad


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    details = argv[argv.index("--details") + 1] if "--details" in argv else None
    only = argv[argv.index("--file") + 1] if "--file" in argv else None
    skip = {argv.index(o) + 1 for o in ("--details", "--file") if o in argv}
    args = [a for i, a in enumerate(argv) if i > 0 and i not in skip and not a.startswith("--")]
    root = os.path.abspath(args[0]) if args else os.path.abspath(os.path.join(here, "..", "..", ".."))
    # Until the registry is split, an ID at or below this is the earlier build's.
    cur_ids, arch_ids = registry_ids(root)
    earlier_max = 261 if not arch_ids else None

    groups = [("strict", expand(root, STRICT)), ("reference", expand(root, REFERENCES)),
              ("history", expand(root, HISTORY))]
    names = ["broken-links"] + list(CHECKS) + ["archived-E"] + list(REF_CHECKS)
    totals = dict.fromkeys(names, 0)
    rows = []
    for kind, files in groups:
        for path in files:
            rel = os.path.relpath(path, root)
            if only and only not in rel:
                continue
            text = open(path, encoding="utf-8").read()
            lines = text.split("\n")
            counts = dict.fromkeys(names, 0)
            hits = {n: [] for n in names}
            for t in broken_links(root, path, text):
                counts["broken-links"] += 1
                hits["broken-links"].append(t)
            if kind != "history":
                for name, rx in CHECKS.items():
                    for i, line in enumerate(lines, 1):
                        for m in rx.finditer(line):
                            if name == "links-to-archive" and any(l in m.group(1) for l in LIVE):
                                continue
                            counts[name] += 1
                            hits[name].append(f"{i}: {m.group(0)[:80]}")
                ids = {int(x) for x in EID.findall(text)}
                if rel != "writeup/record/experiments.md":
                    if earlier_max is not None:
                        gone = sorted(i for i in ids if i <= earlier_max)
                    else:
                        gone = sorted(i for i in ids if i not in cur_ids)
                    counts["archived-E"] = len(gone)
                    hits["archived-E"] = [f"E-{i}" for i in gone]
            if kind == "reference":
                for name, rx in REF_CHECKS.items():
                    for i, line in enumerate(lines, 1):
                        for m in rx.finditer(line):
                            counts[name] += 1
                            hits[name].append(f"{i}: {m.group(0)}")
            rows.append((kind, rel, len(lines), counts, hits))
            for n in names:
                totals[n] += counts[n]

    short = {"broken-links": "links", "earlier-build": "earlier", "history-words": "history", "dates": "dates",
             "iteration-compare": "iter", "links-to-archive": "to-arch", "archived-E": "old-E",
             "commits": "commits", "work-items": "W-n", "plan-rows": "D-n", "branches": "branch",
             "the-users-words": "user/mine"}
    head = f"{'document':44} {'kind':9} {'lines':>6} " + " ".join(f"{short[n]:>9}" for n in names)
    print(head)
    for kind, rel, n, counts, hits in rows:
        print(f"{rel:44} {kind:9} {n:6d} " + " ".join(f"{counts[c]:9d}" for c in names))
    print(f"{'TOTAL':44} {'':9} {sum(r[2] for r in rows):6d} " + " ".join(f"{totals[c]:9d}" for c in names))
    if details:
        print()
        for kind, rel, n, counts, hits in rows:
            if hits.get(details):
                print(f"== {rel} ({details}: {len(hits[details])})")
                for h in hits[details]:
                    print("   " + h)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
