#!/usr/bin/env python3
"""W-158, the port's part: the trim verifier's errors in a build log, by statement and by kind.
usage: kinds.py <log>     A statement is the unresolved call's callee and the innermost frame (function, file:line).
The kinds are E-510's: 1 the callbacks' entry, 2 the call of the object a box holds, 3 Rodas5's chunk, 4 PartialFn
at Any; anything else is "other"."""
import re, sys, collections
def kind(callee, frame):
    s = callee + ' ' + frame
    if 'getfield(_1, :object)' in callee: return '2 box call'
    if re.search(r'dual_jacobian|rodas5_start|_rodas5_run', callee): return '3 Rodas5 chunk'
    if callee.startswith('PartialFn('): return '4 PartialFn at Any'
    if re.search(r'enter_callbacks|enter_step_callbacks|_enter_callback|_enter_step_callback|FunctionCallback|FunctionEventCallback|_hasmethod|to_tuple_type', s): return '1 callbacks entry'
    return 'other'
for path in sys.argv[1:]:
    items = []; kindcur = None; callee = None; frame = None; want_at = False
    for line in open(path, errors='replace'):
        m = re.match(r'^Error #\d+: unresolved (?:call|invoke|argument to call) from statement (.*)$', line)
        if m:
            if callee is not None: items.append((callee, frame))
            callee = m.group(1).strip()[:120]; frame = None; want_at = False; continue
        if callee is not None and frame is None:
            m = re.match(r'^\s*\[1\] (.*)$', line)
            if m: frame = re.sub(r'\{.*', '{…}', m.group(1).split('(')[0] or m.group(1)[:40]); want_at = True; continue
        if want_at:
            m = re.match(r'^\s*@ \S+ (\S+)', line)
            if m: frame += ' ' + re.sub(r'^.*/(lib/|src/|base/)', r'\1', m.group(1)); want_at = False
    if callee is not None: items.append((callee, frame))
    by = collections.Counter(items)
    ks = collections.Counter(kind(c, f or '') for c, f in items)
    print(f"{path.split('/')[-1]}: {len(items)} errors in {len(by)} statements; by kind: " + ', '.join(f"{k} {n}" for k, n in sorted(ks.items())))
    for (c, f), n in sorted(by.items(), key=lambda x: (kind(x[0][0], x[0][1] or ''), x[0][1] or '')):
        print(f"  {n:3d}  [{kind(c, f or '')}] {f} | {c[:90]}")
