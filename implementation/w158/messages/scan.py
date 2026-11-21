#!/usr/bin/env python3
"""Scan collected messages for the forms traits §11.3 keeps out of a message (README.md).

    python3 -I scan.py <records.tsv> [<run output>...]

records.tsv: the lines capture.jl writes, `<source>\t<kind>\t<message, escaped>`. A run's output adds the warnings
Julia's runtime prints itself (`WARNING:` lines), which no logger sees. Prints each finding with the message's line
that holds it, then the counts by form; distinct messages are counted once.
"""
import re
import sys

FORMS = [
    ("tuple type", re.compile(r"Tuple\{typeof\(")),
    ("generated name", re.compile(r"var\"#|#self#|#forwarder#|#entry#|##\w+#\d+|(?<![\w\"])#[A-Za-z_]\w*#\d+")),
    ("compiler object", re.compile(r"MethodInstance for |CodeInstance|Core\.(Dynamic|Compiled)\b")),
    ("library internal", re.compile(r"TraitWorld\._\w+")),
    ("box or wrapper type", re.compile(r"\b(Dynamic|Compiled)\{")),
]


def unescape(s):
    return s.encode("latin-1", "backslashreplace").decode("unicode_escape")


def records(path):
    with open(path, encoding="utf-8", errors="replace") as io:
        for ln in io:
            parts = ln.rstrip("\n").split("\t", 2)
            if len(parts) == 3:
                yield parts[0], parts[1], unescape(parts[2])


def outputs(paths):
    for p in paths:
        with open(p, encoding="utf-8", errors="replace") as io:
            for i, ln in enumerate(io, 1):
                if ln.startswith("WARNING:"):
                    yield f"{p.split('/')[-1]}:{i}", "runtime warning", ln.rstrip("\n")


def main():
    seen = set()
    counts = {name: 0 for name, _ in FORMS}
    total = 0
    findings = []
    for src, kind, msg in list(records(sys.argv[1])) + list(outputs(sys.argv[2:])):
        if msg in seen:
            continue
        seen.add(msg)
        total += 1
        for name, rx in FORMS:
            hits = [ln for ln in msg.split("\n") if rx.search(ln)]
            if hits:
                counts[name] += 1
                findings.append((name, src, kind, hits[0].strip()[:300]))
    for name, src, kind, ln in sorted(findings):
        print(f"{name}\t{src}\t{kind}\t{ln}")
    print(f"# {total} distinct messages; with each form: " +
          ", ".join(f"{name} {n}" for name, n in counts.items()))


if __name__ == "__main__":
    main()
