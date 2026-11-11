#!/usr/bin/env python3
"""Check the code a document quotes from the ports against the ports' files.

A document cites a port's code as `path/to/file.jl:LINE`, in prose or as a
comment on a quoted line inside a code block. This report checks, for each:
  - the file exists under the workspace root, and has that line;
  - a quoted line (code before a `# path:LINE` comment in a code block)
    is the file's line at LINE, compared without whitespace runs.
A citation `# :LINE` reuses the last file named. A path that starts with
`…/` is resolved by its suffix among the files of the ports' directories.

    python3 -I experiments/docs-checks/check_quotes.py writeup/intro/porting.md

One line per citation: OK, MOVED (the quoted line is in the file at another
line), DIFFERS (the quoted line is not in the file), NOLINE, NOFILE,
AMBIGUOUS, or CITED (a prose citation; the file's line is printed, to be read).
Exit status 1 if any citation is not OK or CITED. It changes nothing.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PORTS = ["forks-unified", "TraitDifferentialEquations-unified", "TraitMakie-unified",
         "TraitReport-unified", "TraitTables-unified", "TraitCSV-unified",
         "TraitWorld-unified", "ndport/pkgs/NetworkDynamics-unified",
         "ndport/pkgs/Graphs-unified", "ndport/pkgs/GraphMakie-unified"]
CITE = re.compile(r"((?:…/)?[A-Za-z][\w./-]*\.jl)?:(\d+)\b")


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


_files = None


def port_files():
    global _files
    if _files is None:
        _files = []
        for p in PORTS:
            d = os.path.join(ROOT, p)
            if not os.path.isdir(d):
                continue
            out = subprocess.run(["git", "-C", d, "ls-files", "*.jl"],
                                 capture_output=True, text=True).stdout
            _files += [os.path.join(p, f) for f in out.split()]
    return _files


def resolve(path):
    """Workspace-relative path of a cited file, or a list of candidates."""
    if path.startswith("…/"):
        suffix = path[2:]
        c = [f for f in port_files() if f.endswith("/" + suffix)]
        return c[0] if len(c) == 1 else c
    if os.path.isfile(os.path.join(ROOT, path)):
        return path
    c = [f for f in port_files() if f.endswith("/" + path)]
    return c[0] if len(c) == 1 else c


def main(doc):
    bad = 0
    in_code = False
    last = None
    for n, line in enumerate(open(doc, encoding="utf-8"), 1):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        for m in CITE.finditer(line):
            path, num = m.group(1), int(m.group(2))
            quoted = None
            if in_code:
                hash_at = line.rfind("#", 0, m.start() + 1)
                if hash_at < 0:
                    continue                      # `a:10` in code, not a citation
                quoted = norm(line[:hash_at])
            elif path is None:
                continue                          # a bare `:12` in prose
            if path is None:
                path = last
            if path is None:
                continue
            where = resolve(path)
            tag = f"{doc}:{n}: {path}:{num}"
            if isinstance(where, list):
                print(f"{tag}: {'AMBIGUOUS ' + ', '.join(where) if where else 'NOFILE'}")
                bad += 1
                continue
            last = path
            src = open(os.path.join(ROOT, where), encoding="utf-8").read().split("\n")
            if num > len(src):
                print(f"{tag}: NOLINE ({where} has {len(src)} lines)")
                bad += 1
                continue
            there = norm(src[num - 1])
            if quoted is None or quoted == "":
                print(f"{tag}: CITED  {there[:110]}")
            elif there.startswith(quoted) or quoted.startswith(there.split(" #")[0].strip()):
                print(f"{tag}: OK")
            else:
                at = [i + 1 for i, s in enumerate(src) if norm(s).startswith(quoted)]
                if at:
                    print(f"{tag}: MOVED to line {', '.join(map(str, at))}")
                else:
                    print(f"{tag}: DIFFERS\n    quoted: {quoted[:110]}\n    file:   {there[:110]}")
                bad += 1
    return bad


if __name__ == "__main__":
    total = sum(main(d) for d in sys.argv[1:])
    print(f"-- {total} problems", file=sys.stderr)
    sys.exit(1 if total else 0)
