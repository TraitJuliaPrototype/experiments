import sys, re, subprocess, os
sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
import importlib.util
spec=importlib.util.spec_from_file_location('scrubmod','/tmp/claude-harvest/w19f/tools/scrub.py')
src=open('/tmp/claude-harvest/w19f/tools/scrub.py').read()
# take pats and scrub() without running main
ns={}
exec(src.split("out=subprocess.run")[0].replace("repo, rev = sys.argv[1], sys.argv[2]\npaths = sys.argv[3:]",""), ns)
pats=ns['pats']; buggy=ns['scrub']
def split_comment(line, ext):
    if ext in ('.c','.h','.cpp','.inc'):
        i=line.find('//')
        return (line[:i], line[i:]) if i>=0 else (None, line)
    # julia: a '#' outside a string
    inq=False
    for i,ch in enumerate(line):
        if ch=='"': inq=not inq
        elif ch=='#' and not inq: return (line[:i], line[i:])
    return (None, line)
def tidy(s):
    for _ in range(3):
        s=re.sub(r'\(\s*[,;:]\s+', '(', s)
        s=re.sub(r'\s*[,;:]\s*\)', ')', s)
        s=re.sub(r'\s\(\s*\)', '', s)
        s=re.sub(r'\s+,', ',', s)
        s=re.sub(r',\s*,', ',', s)
    s=re.sub(r'(\S)  +', r'\1 ', s)
    s=re.sub(r' +([.,;])', r'\1', s)
    return s.rstrip()
def safe(line, ext):
    code, com = split_comment(line, ext)
    if code is not None and code.strip()=='' : code=None if False else code
    t=com
    for p in pats: t=re.sub(p,'',t)
    t=tidy(t)
    if code is None:
        return t
    if re.fullmatch(r'\s*(#|//)\s*', t): return code.rstrip()
    return code+t
if __name__=='__main__':
    repo, finrev = sys.argv[1], sys.argv[2]
    files=subprocess.run(['git','-C',repo,'diff','--name-only','HEAD'],capture_output=True,text=True).stdout.split()
    files+=subprocess.run(['git','-C',repo,'ls-files','--others','--exclude-standard'],capture_output=True,text=True).stdout.split()
    fixed=0
    for p in files:
        ext=os.path.splitext(p)[1]
        fin=subprocess.run(['git','-C',repo,'show',f'{finrev}:{p}'],capture_output=True,text=True).stdout
        if not fin: continue
        repl={}
        for l in fin.split('\n'):
            if any(re.search(x,l) for x in pats):
                b=buggy(l); s=safe(l,ext)
                if b!=s: repl[b]=s
        L=open(f'{repo}/{p}').read().split('\n')
        for i,l in enumerate(L):
            if l in repl:
                L[i]=repl[l]; fixed+=1
        open(f'{repo}/{p}','w').write('\n'.join(L))
    print('fixed', fixed)
