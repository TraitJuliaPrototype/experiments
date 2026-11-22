# Applied to each part's tree: series wording kept, scrub residues tidied, datatype.c rebuilt from the
# series' file with the parts' additions only. Idempotent; a replacement whose text is absent is skipped.
import sys, subprocess, re; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import rd, wr
from cfuncs import items
from cmerge import with_comment
def git(*a): return subprocess.run(['git']+list(a),capture_output=True,text=True,check=True).stdout
B='98960887b3'; FIN='8884715703'
def rep(p, old, new):
    try: s=rd(p)
    except FileNotFoundError: return
    if old in s: wr(p, s.replace(old,new))
# 1. boot.jl: the series' comments
base=git('show',B+':base/boot.jl')
rep('base/boot.jl', "# inferred once, at `Any` (`Base.@nospecializeinfer`), and a call's dispatch backedge keeps its own signature", "# inferred once, at `Any` (`Base.@nospecializeinfer`), and a call is matched at its own signature")
rep('base/boot.jl', "# intersections: All{X, Y} is the type of the values that are members of each\n# component; the runtime builds it in its normal form as All{Tuple{X, Y}}", "# intersections: All{X, Y} is the type of the values that are members of each component; the runtime\n# builds it in its normal form as All{Tuple{X, Y}}")
rep('base/boot.jl', "# A membership is a method of `implements`: `S <: X` by a membership holds where it has a method\n# at `(Type{X}, Type{S})`. The runtime defines the method when a membership is declared; its body is\n# the template's.\n", "# A membership is a method of `implements`: `S <: X` by a membership holds where it has a method at\n# `(Type{X}, Type{S})`. The runtime defines the method when a membership is declared, in the\n# membership's world; its body is the template's. Code that relies on the membership holds an edge\n# to the method's instance, and ends when the method does.\n")
# 2. facts.jl: the series' comments
rep('Compiler/src/facts.jl', "    # a trait's operation is open to its members, exported or not\n", "    # a trait's operation is open to the set's members, exported or not\n")
rep('Compiler/src/facts.jl', "(facts )\"", "(reflection)\"")
# 3. Base.jl: the split tables' miss in general terms
rep('base/Base.jl', "# the miss of the split tables while Base is built too: code compiled once at `IO` runs here", "# the miss of the split tables while Base is built too: code with a split runs here")
rep('base/Base.jl', "    # the miss of the compiler's split tables (splittable.jl), first: code compiled once at `IO`\n    # reaches it from the first write to a stream past `IO`'s candidates", "    # the miss of the compiler's split tables (splittable.jl), first: code with a split reaches it\n    # from the first value past the split's candidates")
# 4. abstractinterpretation: a comment that names a later part's box
rep('Compiler/src/abstractinterpretation.jl', "    # (not at a split's own branches: the union of its candidates holds the box `Dynamic{X}`, a type\n    # with a set in it, and is the split already)\n", "    # (not at a split's own branches: they are the split already)\n")
# 5. scrub residues
P='Compiler/src/abstractinterpretation.jl'
rep(P, "# The set `X` where `T` is the wrapper of a value known only by its trait, `Compiled{Z} where Z<:X`\n#: the type", "# The set `X` where `T` is the wrapper of a value known only by its trait, `Compiled{Z} where Z<:X`:\n# the type")
rep(P, "is a forwarder\n#: the call is", "is a forwarder:\n# the call is")
rep(P, "is not checked against\n#: `TRUSTED_CALLABLE` or `TRUSTED_OPERATION`. A closed build leaves no call to dispatch\n#: every call runs", "is not checked against:\n# `TRUSTED_CALLABLE` or `TRUSTED_OPERATION`. A closed build leaves no call to dispatch:\n# every call runs")
rep(P, "        # (trusted, : a member's own instance", "        # (trusted: a member's own instance")
rep(P, "never `Compiled`\n            #, and a call that takes it", "never `Compiled`,\n            # and a call that takes it")
rep(P, "result the join of the branches'\n    #. There is no `A` or `S` to check", "result the join of the branches'.\n    # There is no `A` or `S` to check")
rep('src/gf.c', "how it is compiled is the set's rule,\n        //, and `Function` is merely one of its members)", "how it is compiled is the set's rule,\n        // and `Function` is merely one of its members)")
rep('Compiler/src/stmtinfo.jl', "dispatch in the caller's world and record none, so an invalidation below a candidate stops there\n().\n", "dispatch in the caller's world and record none, so an invalidation below a candidate stops there.\n")
# 6. datatype.c: the series' file with the parts' additions
cur=rd('src/datatype.c')
if 'register_candidate' in cur:
    s=git('show',B+':src/datatype.c'); fin=git('show',FIN+':src/datatype.c')
    open('/tmp/claude-harvest/w19f/fin_dt.c','w').write(fin)
    fi,fo=items(fin)
    adds=['var:jl_set_candidates','var:candidates_lock','register_candidate','unregister_candidates','jl_register_candidate','jl_candidates_of']
    if 'jl_set_erases' in cur: adds.append('jl_set_erases')
    if 'jl_set_member_patterns' in cur: adds+=['jl_set_enumerable','jl_set_member_patterns']
    for k in adds:
        si,so=items(s)
        idx=fo.index(k); anchor=None
        for p in reversed(fo[:idx]):
            if p in si: anchor=p; break
        blk=with_comment(fin, fi[k])
        pos=s.index(si[anchor])+len(si[anchor])
        s=s[:pos]+'\n\n'+blk+s[pos:]
    si,_=items(s)
    f=si['jl_activate_memberships']; k=f.rindex('    JL_GC_POP();')
    g=f[:k]+'''    // the concrete members of the entries in force are their sets' candidates
    nd = NULL;
    for (size_t i = 0; i + 1 < n; i += 2) {
        jl_membership_t *en = (jl_membership_t*)jl_array_ptr_ref(list, i + 1);
        if (jl_atomic_load_relaxed(&en->max_world) == ~(uint64_t)0 && jl_is_concrete_type(en->member))
            register_candidate(en->set, en->member);
    }
'''+f[k:]
    s=s.replace(f,g)
    si,_=items(s); f=si['jl_declare_membership']; k=f.index('    if (jl_declared_memberships == NULL)')
    g=f[:k]+'''    // a concrete member is a candidate of its set, for an operation's split
    if (jl_is_concrete_type(member))
        register_candidate(setname, member);
    // an argument, rooted by the caller: the analyzer moves its root to the svec register_candidate
    // stores it in, and releases it with that frame
    JL_GC_PROMISE_ROOTED(member);
'''+f[k:]
    s=s.replace(f,g)
    si,_=items(s); f=si['jl_delete_membership']; k=f.index('    jl_member_states_forget(found->member, setname);')
    g=f[:k]+'    unregister_candidates(setname, found->member);\n'+f[k:]
    s=s.replace(f,g)
    if 'jl_set_erases' in cur:
        s=s.replace('    tn->never_member = 0;\n','    tn->never_member = 0;\n    tn->erases = 0;\n',1)
    wr('src/datatype.c', s)
