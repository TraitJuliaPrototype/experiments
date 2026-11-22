import re, sys
def rd(p): return open(p).read()
def wr(p,s): open(p,'w').write(s)
def sub(p, old, new, count=1):
    s=rd(p); n=s.count(old)
    if n!=count: raise SystemExit(f"{p}: expected {count} of:\n{old[:300]}\nfound {n}")
    wr(p, s.replace(old,new))
def cut(p, start, end, keep_end=True):
    """delete from the line that starts `start` up to (not including) the line that starts `end`"""
    s=rd(p); i=s.index(start); j=s.index(end, i)
    wr(p, s[:i]+s[j:])
def cutfn(p, header):
    """delete a top-level Julia definition starting with `header` up to its `end` at column 0, with the comments above"""
    s=rd(p); i=s.index(header)
    j=s.index('\nend\n', i)+5
    # comments directly above
    k=s.rfind('\n', 0, i-1)
    while True:
        prev=s.rfind('\n',0,k)
        line=s[prev+1:k]
        if line.startswith('#'): k=prev
        else: break
    wr(p, s[:k+1]+s[j:])
