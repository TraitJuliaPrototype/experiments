#!/usr/bin/env python3
# Takes the references' section numbers and work items out of the lines a patch adds (the series' wording).
import re, sys
def scrub_line(l):
    l = l.replace(" (compiler §4.8, `concrete_eval_eligible`)", " (`concrete_eval_eligible`)")
    l = l.replace("(the induced entry, §2.8)", "(an entry for the type value)")
    l = l.replace("; compiler §5.5)", ")")
    l = l.replace("# (§4.8): those of", "# those of")
    l = re.sub(r" \(compiler §[0-9.]+(, §[0-9.]+)*\)", "", l)
    l = re.sub(r" \(§[0-9.]+(, §[0-9.]+)*\)", "", l)
    l = l.replace(" (C-162)", "")
    return l
for p in sys.argv[1:]:
    out = []
    for l in open(p).read().split('\n'):
        if l.startswith('+') and not l.startswith('+++'):
            l = scrub_line(l)
        out.append(l)
    s = '\n'.join(out)
    s = s.replace("edges of the pairs it rests on\n+        # those of", "edges of the pairs it rests on,\n+        # those of")
    open(p, 'w').write(s)
