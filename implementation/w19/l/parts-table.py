#!/usr/bin/env python3
# W-19 eighth part: the table of the parts built alone, from logs/l-part-<label>.log
import re, glob, os
H = os.path.dirname(os.path.abspath(__file__)) + '/../logs/'
order = ['F4a2', 'F4b2', 'T2a', 'T2b', 'T2d', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9a', 'T9b', 'T9c', 'T10', 'T15',
         'T11', 'T12', 'T13', 'T14', 'T17', 'S3', 'T16a', 'T16b', 'up27']
print('| Part | Commit | Load at start | Wall | `sys.so` (bytes) | Base\'s tests | Gates (pass/all), stage gates | Library |')
print('|---|---|---|---|---|---|---|---|')
for l in order:
    f = H + f'l-part-{l}.log'
    if not os.path.exists(f):
        print(f'| {l} | — | not built | | | | | |'); continue
    s = open(f).read()
    m = re.search(r'# build \d+ \S+ (\S+) start \S+ load (\S+)', s)
    b = re.search(r'BUILD EXIT (\d+) wall (\d+) s.*sys\.so (\d*)', s)
    tests = re.search(r'## Base tests: (.*)', s).group(1) if '## Base tests' in s else ''
    ov = re.search(r'Overall\s*\|\s*(\d+)', s)
    ok = 'SUCCESS' in s
    g = re.search(r'gates: (\d+) passed, (\d+) failed', s)
    sg = re.search(r'stage gates: (\d+) passed, (\d+) failed', s)
    tw = re.search(r"## TraitWorld's suite\n(.*?)(exit \d+)", s, re.S)
    gates = f'{g.group(1)}/{int(g.group(1))+int(g.group(2))}, {sg.group(1)}/{int(sg.group(1))+int(sg.group(2))}' if g and sg else '—'
    bt = f'`{tests}`: {int(ov.group(1)):,} pass' + ('' if ok else ', FAILURE') if ov else f'`{tests}`: did not run'
    lib = (tw.group(2).replace('exit 0', 'passes') if tw else '—')
    print(f'| {l} | {m.group(1) if m else "?"} | {m.group(2) if m else "?"} | {b.group(2) + " s" if b else "build failed"} | {int(b.group(3)):,} | {bt} | {gates} | {lib} |' if b and b.group(3) else f'| {l} | {m.group(1) if m else "?"} | | BUILD EXIT {b.group(1) if b else "?"} | | | | |')
