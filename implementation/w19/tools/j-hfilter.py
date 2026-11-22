#!/usr/bin/env python3
"""hfilter.py <diff> <assign.tsv> <maxpart> <order,comma,separated>  > patch
assign lines: <file>#<n>[:a-b]<TAB><part>   (a-b: line indices of the hunk, 0 = header; later lines win)
A line of a part above maxpart (or not in order) is not applied: '+' dropped, '-' kept as context."""
import sys, re
sys.path.insert(0, '/tmp/claude-harvest/w19f/tools')
import hunks
diff, assign, maxpart, order = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split(',')
rank = {p:i for i,p in enumerate(order)}
A = {}; R = {}
for line in open(assign):
    line=line.split('#!')[0].rstrip()
    if not line.strip() or line.startswith('##'): continue
    k, p = line.split('\t')[:2]
    if ':' in k.split('#')[-1]:
        hid, rng = k.rsplit(':',1); a,b = map(int, rng.split('-'))
        R.setdefault(hid, []).append((a,b,p))
    else:
        A[k] = p
def on(p): return p in rank and rank[p] <= rank[maxpart]
out=[]; missing=[]
for f in hunks.parse(diff):
    sel=[]; delta=0
    for h in f['hunks']:
        hid=h['id']
        if hid not in A and hid not in R: missing.append(hid); continue
        base=A.get(hid,'out')
        parts=[base]*len(h['lines'])
        for a,b,p in R.get(hid,[]):
            for i in range(a, min(b+1, len(h['lines']))): parts[i]=p
        body=[]; changed=False
        for i,l in enumerate(h['lines'][1:], start=1):
            c=l[:1]
            if c=='+':
                if on(parts[i]): body.append(l); changed=True
            elif c=='-':
                if on(parts[i]): body.append(l); changed=True
                else: body.append(' '+l[1:])
            else: body.append(l)
        if not changed: continue
        m=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)', h['lines'][0])
        os_=int(m.group(1))
        ol=sum(1 for l in body if l[:1] in ' -' or l=='\n'); nl=sum(1 for l in body if l[:1] in ' +' or l=='\n')
        body=[l for l in body]
        hdr=f"@@ -{os_},{ol} +{os_+delta},{nl} @@{m.group(5)}\n"
        delta+=nl-ol
        sel.append([hdr]+body)
    if sel:
        out.extend(f['head'])
        for s in sel: out.extend(s)
if missing: sys.stderr.write('unassigned: '+' '.join(missing)+'\n')
sys.stdout.write(''.join(out))
