#!/usr/bin/env python3
"""Scrub the references' section numbers, work items, experiments and open issues from the lines a
working tree adds against a commit:  scrub.py <repo> <rev> [paths...]"""
import sys, re, subprocess
repo, rev = sys.argv[1], sys.argv[2]
paths = sys.argv[3:]
REF = r'(?:(?:compiler|traits|facts|lowering|proofs|design)\s+)?§\s?[0-9][\w.]*(?:\s*\([a-z]\))?'
pats = [
    REF + r'(?:\s*(?:,|and)\s*' + REF + r')*',
    r'open issues? \d+(?:\s*\([a-z]\))?(?:\s*(?:,|and)\s*\d+(?:\s*\([a-z]\))?)*',
    r'\b(?:W|E|C|GT|D|L|T|F|PE)-\d+[a-z]?(?:\s*\([a-z]\))?(?:\s*(?:,|to|and)\s*(?:W|E|C|GT|D|L|T|F|PE)?-?\d+[a-z]?)*',
    r'\bLemma [A-Z]\b',
]
def scrub(line):
    s=line
    for p in pats:
        s=re.sub(p, '', s)
    # tidy punctuation left behind
    for _ in range(3):
        s=re.sub(r'\(\s*[,;:]\s*', '(', s)
        s=re.sub(r'\s*[,;:]\s*\)', ')', s)
        s=re.sub(r'\(\s*\)', '', s)
        s=re.sub(r'\s+,', ',', s)
        s=re.sub(r',\s*,', ',', s)
        s=re.sub(r'\(\s*(?:see|cf\.)\s*\)', '', s)
    s=re.sub(r'(\S)  +', r'\1 ', s)
    s=re.sub(r' +([.,;:])', r'\1', s)
    s=s.rstrip()
    return s
out=subprocess.run(['git','-C',repo,'diff','-U0',rev,'--']+paths,capture_output=True,text=True).stdout
cur=None; edits={}
for l in out.split('\n'):
    if l.startswith('+++ '):
        cur=l[6:] if l.startswith('+++ b/') else None
    elif l.startswith('@@') and cur:
        m=re.match(r'@@ -\S+ \+(\d+)(?:,(\d+))? @@',l); ln=int(m.group(1)); 
    elif l.startswith('+') and cur and not l.startswith('+++'):
        edits.setdefault(cur,[]).append(ln); ln+=1
# untracked new files: all lines
for p in subprocess.run(['git','-C',repo,'ls-files','--others','--exclude-standard','--']+paths,capture_output=True,text=True).stdout.split():
    n=len(open(f'{repo}/{p}').read().split('\n'))
    edits[p]=list(range(1,n+1))
changed=0
for p,lns in edits.items():
    fp=f'{repo}/{p}'
    try: L=open(fp).read().split('\n')
    except Exception: continue
    for ln in lns:
        if ln-1 < len(L):
            old=L[ln-1]
            if any(re.search(x, old) for x in pats):
                new=scrub(old)
                if new!=old: L[ln-1]=new; changed+=1
    open(fp,'w').write('\n'.join(L))
print('scrubbed', changed)
