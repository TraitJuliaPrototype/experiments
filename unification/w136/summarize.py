#!/usr/bin/env python3
"""E-362: read logs/<case>.<form>.out and print a table: the last phase reached, the exception, the
message's lines and bytes, the stack's frames, where the first frame lies, the warnings.
Two counts find a pattern in the messages' form (open issue 177): signatures printed as a tuple type
("Tuple{typeof(") in the message and the warnings, and the library's own frames above the user's line.
The message is the text from "ERROR: " to "Stacktrace:"; a frame is a line "[n] ..."; a frame's place is
the "@ <module> <file>:<line>" line after it. Workspace paths are shortened."""
import re, glob, os
H = os.path.dirname(os.path.abspath(__file__))
rows = []
for path in sorted(glob.glob(os.path.join(H, 'logs', '*.out'))):
    case, form = os.path.basename(path)[:-4].rsplit('.', 1)
    text = open(path, errors='replace').read()
    lines = text.split('\n')
    phase = [l[6:] for l in lines if l.startswith('PHASE ')]
    warn = sum(1 for l in lines if re.match(r'^(┌|\[) ?Warning', l) or l.startswith('WARNING'))
    err = next((i for i, l in enumerate(lines) if l.startswith('ERROR: ')), None)
    if err is None:
        raw = sum(l.count('Tuple{typeof(') for l in lines)
        rows.append((case, form, phase[-1] if phase else '-', 'none', '', '', '', '', warn, raw, '')); continue
    st = next((i for i in range(err, len(lines)) if lines[i].startswith('Stacktrace:')), len(lines))
    msg = lines[err:st]
    while msg and not msg[-1].strip(): msg.pop()
    first = re.sub(r'^ERROR: (LoadError: )?', '', msg[0])
    exc = re.match(r'([A-Za-z_.]+Error|[A-Za-z_.]+Exception)', first)
    exc = exc.group(1) if exc else first.split(':')[0][:30]
    frames = [i for i in range(st, len(lines)) if re.match(r'^\s*\[\d+\] ', lines[i])]
    place = ''
    for i in frames:
        m = re.match(r'^\s*@ (.*)$', lines[i + 1]) if i + 1 < len(lines) else None
        if m and 'TraitWorld-unified/src' not in m.group(1) and not re.search(r'\./|boot\.jl|Base ', m.group(1)):
            place = re.sub(r'\S*/w136/', '', m.group(1)); break
    top = ''
    if frames:
        m = re.match(r'^\s*@ (.*)$', lines[frames[0] + 1]) if frames[0] + 1 < len(lines) else None
        top = re.sub(r'\S*/(w136|TraitWorld-unified)/', r'\1/', m.group(1)).replace('w136/', '') if m else ''
    raw = sum(l.count('Tuple{typeof(') for l in lines[:st])
    above = 0
    for i in frames:
        nxt = lines[i + 1] if i + 1 < len(lines) else ''
        if 'TraitWorld-unified/src' in nxt: above += 1
        else: break
    rows.append((case, form, phase[-1] if phase else '-', exc, len(msg), len('\n'.join(msg).encode()), len(frames), top + ' ; ' + place, warn, raw, above))
print('| Case | Form | Last phase reached | Exception | Message lines | Message bytes | Frames | First frame; first frame outside Julia and the library\'s runtime | Warnings | Signatures as tuple types | Library frames above the user\'s |')
print('|---|---|---|---|---|---|---|---|---|---|---|')
for r in rows: print('| ' + ' | '.join(str(x) for x in r) + ' |')
