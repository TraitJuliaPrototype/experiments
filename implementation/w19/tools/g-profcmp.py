# W-19, third part: compare the profiles of two builds (motiv/g-profile.jl's tsv files), by function: the mean samples
# whose stack holds it, and where it is the leaf.   python3 g-profcmp.py <a1.tsv,a2.tsv,...> <b1.tsv,...> [incl|self] [rows]
import sys,collections
def load(fs):
    d=collections.defaultdict(list); s=[]
    for f in fs:
        L=open(f).read().splitlines(); s.append(int(L[0].split('\t')[3]))
        dd={}
        for l in L[1:]:
            c,se,n=l.split('\t',2); dd[n]=(int(c),int(se))
        for n,v in dd.items(): d[n].append(v)
    return d,s
a,sa=load(sys.argv[1].split(',')); b,sb=load(sys.argv[2].split(','))
na,nb=len(sa),len(sb)
print("samples",sa,sb)
rows=[]
for n in set(a)|set(b):
    ia=sum(x[0] for x in a.get(n,[]))/na; ib=sum(x[0] for x in b.get(n,[]))/nb
    sa_=sum(x[1] for x in a.get(n,[]))/na; sb_=sum(x[1] for x in b.get(n,[]))/nb
    rows.append((ib-ia,ia,ib,sa_,sb_,n))
key=sys.argv[3] if len(sys.argv)>3 else 'incl'
if key=='self': rows.sort(key=lambda r:-(r[4]-r[3]))
else: rows.sort(key=lambda r:-abs(r[0]))
for r in rows[:int(sys.argv[4]) if len(sys.argv)>4 else 40]:
    print("%7.1f %7.1f %7.1f | self %6.1f %6.1f | %s"%(r[0],r[1],r[2],r[3],r[4],r[5][:110]))
