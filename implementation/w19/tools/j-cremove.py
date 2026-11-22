import sys
sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from cfuncs import items
from cmerge import with_comment
p=sys.argv[1]
for k in sys.argv[2:]:
    s=open(p).read(); it,_=items(s)
    blk=with_comment(s, it[k])
    i=s.index(blk)
    j=i+len(blk)
    while j < len(s) and s[j]=='\n' and s[j+1:j+2]=='\n': j+=1
    s=s[:i]+s[j+1:]
    open(p,'w').write(s)
