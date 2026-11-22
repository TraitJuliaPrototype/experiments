#!/usr/bin/env python3
"""W-19: the top-level definitions of base/*.jl that a patch changes, as Julia source to evaluate
into vanilla's Base: `defs_of_patch.py <repo> <base> <branch>` prints, for each file of base/ the
patch touches, `#= file =#` and each changed definition's text from the branch, in file order.
A definition spans from a line at column 0 that starts it (function, macro, `@...`, `name(...) =`)
to the next line at column 0 that is `end`, or to the line before the next non-blank column-0 line."""
import subprocess, sys, re
repo, base, br = sys.argv[1:4]
git = lambda *a: subprocess.run(['git','-C',repo]+list(a),capture_output=True,text=True).stdout
for f in git('diff','--name-only',base,br).split():
    if not (f.startswith('base/') and f.endswith('.jl')): continue
    src = git('show', f'{br}:{f}').splitlines()
    changed=set()
    for l in git('diff','-U0',base,br,'--',f).splitlines():
        m=re.match(r'@@ -\S+ \+(\d+)(?:,(\d+))? @@', l)
        if m:
            a=int(m.group(1)); c=int(m.group(2) or 1); changed.update(range(a, a+max(c,1)))
    spans=[]; i=0; n=len(src)
    while i<n:
        l=src[i]
        if l and not l[0].isspace() and not l.startswith(('#','"""','end')):
            if re.match(r'^(function|macro|@)', l) and not re.search(r'\bend\s*$', l) and not re.match(r'^@\w+\s+\S+\s*=', l) and ('function' in l or l.startswith('@assume_effects')):
                k=i+1
                while k<n and not src[k].startswith('end'): k+=1
                spans.append((i+1,k+1)); i=k+1; continue
            k=i+1
            while k<n and (not src[k] or src[k][0].isspace()) and not src[k].startswith('"""'): k+=1
            spans.append((i+1,k)); i=k; continue
        i+=1
    print(f'#= {f} =#')
    for a,b in spans:
        if any(a<=x<=b for x in changed):
            print('\n'.join(src[a-1:b])); print()
