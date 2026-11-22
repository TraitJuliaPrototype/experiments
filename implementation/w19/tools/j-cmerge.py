#!/usr/bin/env python3
"""cmerge.py <series.c> <final.c> add=<k1,k2> replace=<k3,...>  -> writes merged series file in place.
Items keyed as by cfuncs.items; an added item brings its preceding comment block from final."""
import sys, re
sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from cfuncs import items
def with_comment(text, body):
    lines=text.split('\n'); bl=body.split('\n')
    # find the item's first line index in text
    for i in range(len(lines)):
        if lines[i:i+len(bl)]==bl:
            j=i
            while j>0 and (lines[j-1].lstrip().startswith(('//','/*','*')) or lines[j-1].rstrip().endswith('*/')):
                j-=1
            return '\n'.join(lines[j:i+len(bl)])
    return body
def main():
    sp, fp = sys.argv[1], sys.argv[2]
    add=[];rep=[]
    for a in sys.argv[3:]:
        k,v=a.split('=',1)
        (add if k=='add' else rep).extend([x for x in v.split(',') if x])
    st=open(sp).read(); ft=open(fp).read()
    si,so=items(st); fi,fo=items(ft)
    for k in rep:
        assert k in si and k in fi, k
        st=st.replace(si[k], fi[k],1)
    for k in add:
        assert k in fi and k not in si, k
        si,so=items(st)
        idx=fo.index(k); anchor=None
        for p in reversed(fo[:idx]):
            if p in si: anchor=p; break
        blk=with_comment(ft, fi[k])
        if anchor is None:
            raise SystemExit('no anchor for '+k)
        pos=st.index(si[anchor])+len(si[anchor])
        st=st[:pos]+'\n\n'+blk+st[pos:]
    open(sp,'w').write(st)
if __name__=="__main__": main()
