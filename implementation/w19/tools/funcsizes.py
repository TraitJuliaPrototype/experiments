#!/usr/bin/env python3
"""W-19: the lines a diff adds, by function of the new tree.
usage: funcsizes.py <julia repo> <base> <head> [paths...]
For every file of the diff, the added lines (new-file line numbers) are assigned to the function
whose span holds them: C/C++ functions (a line at column 0 with '(' and a '{' line at column 0
before the next ';'), ending at '^}'; Julia functions ('function f', 'macro m', 'f(...) =' at any
indentation of the top level or one struct level), ending at the 'end' of the same indentation;
a one-line definition is a span of one line. Lines outside every span are counted as '<toplevel>'.
Removed lines are counted per file only. Prints: file, function, added lines; largest first."""
import subprocess, sys, re, collections
repo, base, head = sys.argv[1:4]; paths = sys.argv[4:]
def git(*a): return subprocess.run(['git','-C',repo]+list(a),capture_output=True,text=True,errors='replace').stdout
diff = git('diff','-U0',base,head,'--',*paths)
added = collections.defaultdict(list); removed = collections.Counter(); cur=None
for l in diff.splitlines():
    if l.startswith('+++ '): cur = l[6:] if l.startswith('+++ b/') else None
    elif l.startswith('@@') and cur:
        m = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', l)
        n0=int(m.group(3)); c=int(m.group(4) or 1)
        added[cur].extend(range(n0, n0+c)); removed[cur]+= int(m.group(2) or 1) if m.group(2)!='0' else 0
def spans_c(lines):
    sp=[]; i=0; n=len(lines)
    while i<n:
        l=lines[i]
        if re.match(r'^[A-Za-z_].*\(', l) and not l.rstrip().endswith(';') and not l.startswith(('typedef','struct','#','static_assert')):
            j=i
            while j<n and j<i+8 and not lines[j].startswith('{') and not lines[j].rstrip().endswith('{'): 
                if lines[j].rstrip().endswith(';'): break
                j+=1
            if j<n and (lines[j].startswith('{') or lines[j].rstrip().endswith('{')) and not lines[j].rstrip().endswith(';'):
                k=j+1
                while k<n and not lines[k].startswith('}'): k+=1
                name=re.findall(r'([A-Za-z_][A-Za-z_0-9]*)\s*\(', l)
                sp.append((i+1,k+1,(name[0] if name else l[:40]).strip())); i=k+1; continue
        i+=1
    return sp
def spans_jl(lines):
    sp=[]; n=len(lines)
    for i,l in enumerate(lines):
        m=re.match(r'^(\s{0,4})((?:@\w+(?:\s+:\w+)*\s+)*)(function|macro)\s+([^\s(]+)', l)
        if m:
            ind=m.group(1); k=i+1
            if re.search(r'\bend\s*$', l) and l.count('function')==1 and ' end' in l: sp.append((i+1,i+1,m.group(4))); continue
            while k<n and not re.match('^'+ind+r'end\b', lines[k]): k+=1
            sp.append((i+1,k+1,m.group(4))); continue
        m=re.match(r'^(\s{0,4})((?:@\w+\s+)*)([A-Za-z_][\w.!]*(?:\{[^}]*\})?)\(.*\)\s*(?:::[^=]+)?(?:where.*)?=(?!=)', l)
        if m and not l.strip().startswith(('#','if ','elseif','return','for ','while ')):
            # a one-line definition, or one whose body continues on indented lines
            k=i+1
            while k<n and lines[k].startswith(m.group(1)+'    ') : k+=1
            sp.append((i+1,k,m.group(3)))
    return sp
res=collections.Counter()
for f,ls in added.items():
    try: src=git('show',f'{head}:{f}').splitlines()
    except Exception: continue
    sp = spans_jl(src) if f.endswith('.jl') else spans_c(src) if f.endswith(('.c','.cpp','.h')) else []
    for ln in ls:
        best=None
        for a,b,name in sp:
            if a<=ln<=b and (best is None or a>best[0]): best=(a,b,name)
        res[(f, best[2] if best else '<toplevel>')]+=1
for (f,fn),c in res.most_common():
    print(f"{c}\t{f}\t{fn}")
