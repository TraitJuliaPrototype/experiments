#!/usr/bin/env python3
"""Parse a unified diff into hunks; print a summary or write a filtered patch.
  hunks.py summary <diff>
  hunks.py filter <diff> <assign.tsv> <maxpart> > patch   (assign: id<TAB>part; parts ordered by list)
"""
import sys, re
KEYS = ['split','candidate','Callable','callable','trusted','TRUSTED','closed','Closed','CLOSED','Dynamic','Compiled','erases',
        'trait_option','module_option','DefinitionCheck','contract','IOContext','declared','operation','member','set','implements',
        'fully_typed','facts','owner','loaded','closed_after_load','is_trait_arg','forward','expansion','keep','overlay','verify']
def parse(path):
    files=[]; cur=None; h=None
    for line in open(path, encoding='utf-8', errors='surrogateescape'):
        if line.startswith('diff --git'):
            cur={'head':[line],'hunks':[],'name':line.split(' b/')[-1].strip()}; files.append(cur); h=None
        elif line.startswith('@@'):
            h={'lines':[line]}; cur['hunks'].append(h)
        elif h is None:
            cur['head'].append(line)
        else:
            h['lines'].append(line)
    hid=0
    for f in files:
        for i,h in enumerate(f['hunks']):
            h['id']=f"{f['name']}#{i}"
    return files
def summary(path):
    for f in parse(path):
        for h in f['hunks']:
            add=sum(1 for l in h['lines'][1:] if l.startswith('+')); rm=sum(1 for l in h['lines'][1:] if l.startswith('-'))
            body=''.join(l for l in h['lines'][1:] if l[:1] in '+-')
            ks=[k for k in KEYS if k in body]
            hdr=h['lines'][0].split('@@')[-1].strip()[:60]
            print(f"{h['id']}\t+{add}-{rm}\t{hdr}\t{','.join(ks)}")
def filt(path, assign, maxpart, order):
    a={}
    for line in open(assign):
        line=line.rstrip('\n')
        if not line or line.startswith('#'): continue
        k,v=line.split('\t')[:2]; a[k]=v
    rank={p:i for i,p in enumerate(order)}
    out=[]
    missing=[]
    for f in parse(path):
        sel=[]
        for h in f['hunks']:
            p=a.get(h['id'])
            if p is None: missing.append(h['id']); continue
            if p in rank and rank[p] <= rank[maxpart]: sel.append(h)
        if sel:
            out.extend(f['head']); 
            for h in sel: out.extend(h['lines'])
    if missing: sys.stderr.write('unassigned: '+' '.join(missing)+'\n')
    sys.stdout.write(''.join(out))
if __name__=='__main__':
    if sys.argv[1]=='summary': summary(sys.argv[2])
    elif sys.argv[1]=='filter': filt(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5].split(','))

def is_comment(fname, s):
    t=s.strip()
    if not t: return True
    if fname.endswith(('.jl',)): return t.startswith('#')
    if fname.endswith('.scm'): return t.startswith(';')
    return t.startswith('//') or t.startswith('/*') or t.startswith('*') or t.endswith('*/')
def classify(path):
    for f in parse(path):
        for h in f['hunks']:
            ch=[l[1:] for l in h['lines'][1:] if l[:1] in '+-']
            # strip trailing comments in C/Julia code lines for comparison
            def code(s):
                if f['name'].endswith('.jl'):
                    s=re.sub(r'\s+#[^"]*$','',s)
                elif f['name'].endswith(('.c','.h','.cpp','.inc')):
                    s=re.sub(r'\s*//.*$','',s)
                return s.rstrip()
            plus=[];minus=[]
            if f['name'].endswith('.jl'):
                # docstrings: lines within triple quotes (tracked over the old and the new side), or a one-line string
                for side,dst in (('+',plus),('-',minus)):
                    inq=False
                    for l in h['lines'][1:]:
                        if l[:1] not in (' ',side): continue
                        t=l[1:].strip()
                        if t.count('"""')%2==1:
                            inq=not inq; continue
                        if inq or (t.startswith('"') and t.endswith('"') and len(t)>1): continue
                        if l[:1]==side and not is_comment(f['name'],l[1:]): dst.append(code(l[1:]))
            else:
                plus=[code(l[1:]) for l in h['lines'][1:] if l.startswith('+') and not is_comment(f['name'],l[1:])]
                minus=[code(l[1:]) for l in h['lines'][1:] if l.startswith('-') and not is_comment(f['name'],l[1:])]
            kind='comment' if plus==minus else 'code'
            add=sum(1 for l in h['lines'][1:] if l.startswith('+')); rm=sum(1 for l in h['lines'][1:] if l.startswith('-'))
            body=''.join(l for l in h['lines'][1:] if l[:1] in '+-')
            ks=[k for k in KEYS if k in body]
            hdr=h['lines'][0].split('@@')[-1].strip()[:50]
            print(f"{h['id']}\t{kind}\t+{add}-{rm}\t{hdr}\t{','.join(ks)}")
if __name__=='__main__' and sys.argv[1]=='classify': classify(sys.argv[2])
