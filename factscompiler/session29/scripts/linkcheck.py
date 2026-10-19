# Relative markdown links in the design repo's current documents that do not resolve.
import os, re, sys
root = "/home/hellmann/Repos/julia-trait-bound"
docs = [os.path.join(root, "README.md")]
for d, _, fs in os.walk(os.path.join(root, "writeup")):
    docs += [os.path.join(d, f) for f in fs if f.endswith(".md")]
bad = 0
for p in sorted(docs):
    s = open(p).read()
    for m in re.finditer(r"\]\(([^)#\s]+)(#[^)]*)?\)", s):
        t = m.group(1)
        if re.match(r"[a-z]+:", t): continue
        q = os.path.normpath(os.path.join(os.path.dirname(p), t))
        if not os.path.exists(q):
            bad += 1; print(f"{os.path.relpath(p, root)}: {t}")
print("broken:", bad)
