#!/usr/bin/env python3
# The seventh part's restack of the traits series (W-19): each step cherry-picks a commit of the sixth part's
# stack (`w19-traits-v2-head`) onto the stack being made, applies the rows' patches that belong to that part
# (`patches/`), inserts the part's new testsets (`k-tests/`) and commits, with the old message or a new one
# (`msgs/`). A step whose pick or patch conflicts stops; resolve in the tree, then `--resume`.
#     python3 k-restack.py <tree> <steps.txt> [--resume]
# steps.txt: one step per line:
#     base <rev>
#     pick <sha> [apply=<p1>,<p2>] [tests=<file>@<anchor-file>:<before|after>] [msg=<file>] [name=<label>]
#     patch <label> apply=<p>[,...] msg=<file>       (a commit made of patches alone)
import os, subprocess, sys, json, shlex
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
_spec = importlib.util.spec_from_file_location('k_msgfilter', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'k-msgfilter.py'))
_mod = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_mod)
filter_msg = _mod.filter_msg

HERE = os.path.dirname(os.path.abspath(__file__))

def sh(tree, *args, check=True, capture=True):
    r = subprocess.run(list(args), cwd=tree, text=True,
                       stdout=subprocess.PIPE if capture else None, stderr=subprocess.STDOUT if capture else None)
    if check and r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)}: {r.stdout}")
    return r

def parse(path):
    steps = []
    for line in open(path):
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        parts = shlex.split(line)
        st = {'op': parts[0], 'arg': parts[1] if len(parts) > 1 else None}
        for kv in parts[2:]:
            k, v = kv.split('=', 1)
            st[k] = v
        steps.append(st)
    return steps

def subops(st):
    ops = []
    if st['op'] == 'pick':
        ops.append(('pick', st['arg']))
    for p in (st.get('apply') or '').split(','):
        if p:
            ops.append(('apply', p))
    for t in (st.get('tests') or '').split(';'):
        if t:
            ops.append(('tests', t))
    ops.append(('commit', None))
    return ops

def unmerged(tree):
    return [l for l in sh(tree, 'git', 'diff', '--name-only', '--diff-filter=U').stdout.split('\n') if l]

def insert_tests(tree, spec):
    # <content-file>@<file-in-tree>@<anchor-file>:<before|after>
    content, target, anchorspec = spec.split('@')
    anchor_file, where = anchorspec.rsplit(':', 1)
    text = open(os.path.join(HERE, 'k-tests', content)).read()
    anchor = open(os.path.join(HERE, 'k-tests', anchor_file)).read()
    p = os.path.join(tree, target)
    s = open(p).read()
    if s.count(anchor) != 1:
        raise RuntimeError(f"anchor {anchor_file} found {s.count(anchor)} times in {target}")
    i = s.index(anchor)
    if where == 'after':
        i += len(anchor)
        text = '\n' + text
    else:
        text = text + '\n'
    s = s[:i] + text + s[i:]
    open(p, 'w').write(s)
    sh(tree, 'git', 'add', target)

def main():
    tree, stepsfile = sys.argv[1], sys.argv[2]
    resume = '--resume' in sys.argv
    statef = stepsfile + '.state.json'
    steps = parse(stepsfile)
    state = json.load(open(statef)) if resume and os.path.exists(statef) else {'step': 0, 'sub': 0, 'map': []}
    if not resume:
        assert steps[0]['op'] == 'base'
        sh(tree, 'git', 'checkout', '-q', '--detach', steps[0]['arg'])
        state = {'step': 1, 'sub': 0, 'map': []}
    while state['step'] < len(steps):
        st = steps[state['step']]
        ops = subops(st)
        while state['sub'] < len(ops):
            kind, arg = ops[state['sub']]
            json.dump(state, open(statef, 'w'))
            if kind == 'pick':
                r = sh(tree, 'git', '-c', 'rerere.enabled=true', '-c', 'rerere.autoupdate=true',
                       'cherry-pick', '--no-commit', arg, check=False)
                if r.returncode != 0:
                    left = unmerged(tree)
                    marks = sh(tree, 'git', 'diff', '--cached', '-S<<<<<<<', '--name-only', check=False).stdout.strip()
                    if left or marks:
                        print(f"STOP step {state['step']} ({st.get('name', arg)}): pick {arg} conflicts in {left or marks}")
                        state['sub'] += 1; json.dump(state, open(statef, 'w')); sys.exit(1)
                    print(f"  pick {arg}: conflicts resolved by rerere")
            elif kind == 'apply':
                r = sh(tree, 'git', 'apply', '--index', '-3', os.path.join(HERE, 'patches', arg), check=False)
                if r.returncode != 0 or unmerged(tree):
                    print(f"STOP step {state['step']} ({st.get('name', st['arg'])}): apply {arg}:\n{r.stdout}")
                    state['sub'] += 1; json.dump(state, open(statef, 'w')); sys.exit(1)
            elif kind == 'tests':
                insert_tests(tree, arg)
            elif kind == 'commit':
                if unmerged(tree):
                    print("STOP: unmerged paths remain"); sys.exit(1)
                if 'msg' in st:
                    text = open(os.path.join(HERE, 'msgs', st['msg'])).read()
                elif st['op'] == 'pick':
                    text = sh(tree, 'git', 'log', '-1', '--format=%B', st['arg']).stdout
                else:
                    raise RuntimeError('a patch step needs msg=')
                text = filter_msg(text).rstrip('\n') + '\n'
                mf = statef + '.msg'
                open(mf, 'w').write(text)
                author = []
                if st['op'] == 'pick':
                    a = sh(tree, 'git', 'log', '-1', '--format=%an <%ae>%n%ad', st['arg']).stdout.split('\n')
                    author = ['--author', a[0], '--date', a[1]]
                sh(tree, 'git', '-c', 'rerere.enabled=true', 'commit', '-q', '--allow-empty', *author, '-F', mf)
                head = sh(tree, 'git', 'rev-parse', '--short=10', 'HEAD').stdout.strip()
                state['map'].append([st.get('name', st['arg']), head])
                print(f"  {state['step']:3d} {st.get('name', st['arg'])}: {head}")
            state['sub'] += 1
        state['step'] += 1; state['sub'] = 0
        json.dump(state, open(statef, 'w'))
    print("done")

main()
