# W-157: two censuses' tables of culprits compared by method name (census.jl's $CENSUS_TSV): the culprit
# instances of each name before and after, and the cones they are in; the names a batch removed or added.
#     python3 diag/compare.py logs/<before>.tsv logs/<after>.tsv [name-pattern...]
import sys, re

def read(p):
    out = {}
    with open(p) as f:
        next(f)
        for line in f:
            m, k, inst, cone, alone = line.rstrip('\n').split('\t')
            out[m] = (k, int(inst), int(cone), int(alone))
    return out

a, b = read(sys.argv[1]), read(sys.argv[2])
pats = [re.compile(x) for x in sys.argv[3:]]
names = sorted(set(a) | set(b), key=lambda n: -(a.get(n, ('', 0, 0, 0))[2]))
print(f"{'method':46} {'inst before':>11} {'after':>6} {'cones before':>12} {'after':>6}")
gone = new = 0
for n in names:
    ka = a.get(n, ('', 0, 0, 0)); kb = b.get(n, ('', 0, 0, 0))
    if ka[1] and not kb[1]: gone += 1
    if kb[1] and not ka[1]: new += 1
    if pats and not any(p.search(n) for p in pats): continue
    if not pats and ka[1] == kb[1] and ka[2] == kb[2]: continue
    print(f"{n[:46]:46} {ka[1]:>11} {kb[1]:>6} {ka[2]:>12} {kb[2]:>6}")
print(f"# names with culprits before {len(a)}, after {len(b)}; gone {gone}, new {new}; "
      f"culprit instances before {sum(v[1] for v in a.values())}, after {sum(v[1] for v in b.values())}")
