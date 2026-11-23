#!/usr/bin/env python3
# Split a patch into hunks and write a patch of the hunks chosen: k-hunks.py <patch> list | keep <ids> | drop <ids>
# A hunk's id is <file>:<n>, n counted from 1 within the file.
import sys, re
def parse(path):
    files = []; cur = None; h = None
    for line in open(path).read().split('\n')[:-1]:
        if line.startswith('diff --git'):
            cur = {'head': [line], 'hunks': []}; files.append(cur); h = None
        elif cur is None:
            continue
        elif line.startswith('@@'):
            h = [line]; cur['hunks'].append(h)
        elif h is None:
            cur['head'].append(line)
        else:
            h.append(line)
    return files
def name(f): return f['head'][0].split(' b/')[-1]
files = parse(sys.argv[1]); mode = sys.argv[2]
if mode == 'list':
    for f in files:
        for i, h in enumerate(f['hunks'], 1):
            print(f"{name(f)}:{i}  {h[0][:100]}")
    sys.exit()
ids = set(sys.argv[3].split(','))
out = []
for f in files:
    keep = [h for i, h in enumerate(f['hunks'], 1) if ((f"{name(f)}:{i}" in ids) == (mode == 'keep'))]
    if keep:
        out += f['head']
        for h in keep: out += h
print('\n'.join(out))
