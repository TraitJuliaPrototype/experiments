#!/usr/bin/env python3
"""Top-level items of a C file by name; compare two versions.  cfuncs.py <old.c> <new.c>"""
import sys, re
def strip_comments(s):
    s=re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s=re.sub(r'//[^\n]*', '', s)
    return '\n'.join(l.rstrip() for l in s.splitlines() if l.strip())
def items(text):
    lines=text.split('\n'); out={}; order=[]
    i=0; n=len(lines)
    while i<n:
        l=lines[i]
        if l and not l[0].isspace() and not l.startswith(('//','/*','#','}',' *')) and '(' in l and not l.rstrip().endswith(';'):
            # find start of body
            j=i
            while j<n and '{' not in lines[j] and not lines[j].rstrip().endswith(';'): j+=1
            if j<n and '{' in lines[j]:
                depth=0; k=j
                while k<n:
                    depth+=lines[k].count('{')-lines[k].count('}')
                    if depth<=0 and ('}' in lines[k]): break
                    k+=1
                m=re.search(r'(\w+)\s*\(', l)
                name=m.group(1) if m else l
                if name in ('JL_DLLEXPORT','static'): name=l
                key=name
                c=1
                while key in out: c+=1; key=f"{name}@{c}"
                out[key]='\n'.join(lines[i:k+1]); order.append(key)
                i=k+1; continue
        m=re.match(r'^(?:static |JL_DLLEXPORT |extern )*[\w\s\*]+?\b(\w+)\s*(?:\[.*\])?\s*(?:JL_GLOBALLY_ROOTED\s*)?(=|;)', l)
        if m and not l[0].isspace():
            key='var:'+m.group(1)
            k=i
            while k<n and not lines[k].rstrip().endswith(';'): k+=1
            out[key]='\n'.join(lines[i:k+1]); order.append(key); i=k+1; continue
        i+=1
    return out, order
if __name__=='__main__':
    a,_=items(open(sys.argv[1]).read()); b,ob=items(open(sys.argv[2]).read())
    for k in ob:
        if k not in a: print(f"+ {k}\t{len(b[k].splitlines())}")
        elif strip_comments(a[k])!=strip_comments(b[k]): print(f"~ {k}\t{len(b[k].splitlines())}")
    for k in a:
        if k not in b: print(f"- {k}\t{len(a[k].splitlines())}")
