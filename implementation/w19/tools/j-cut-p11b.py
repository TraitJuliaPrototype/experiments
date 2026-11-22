import sys, subprocess, os; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
def git(*a): return subprocess.run(['git']+list(a),capture_output=True,text=True,check=True).stdout
B='98960887b3'
P='Compiler/src/abstractinterpretation.jl'
s=rd(P); i=s.index("const MAX_OPERATION_SPLITS = 4\n"); j=s.index("# The effects of a call whose result is a declared result its members' own code is not checked against", i)
s=s[:i]+s[j:]; wr(P,s)
sub(P, '''                                  sv::AbsIntState, max_methods::Int;
                                  operation::Bool = true)''', '''                                  sv::AbsIntState, max_methods::Int)''')
s=rd(P); i=s.index("    # an operation of a set at a receiver typed by the set\n    # (not at a split's own branches"); j=s.index("    matches = find_method_matches(interp, argtypes, atype; max_methods)\n", i)
s=s[:i]+'''    # an operation of a set at a receiver typed by the set: the operation's declared result, the call
    # left to dispatch and its result asserted
    drt = declared_operation_result(interp, argtypes, atype)
    if drt !== nothing
        # (trusted: a member's own instance is not checked against the declared result in every world
        # it runs in, a member of a pattern before its first use among them; nothing is trusted where
        # the result is `Any`)
        opeffects = drt === Any ? Effects() : trusted_effects(interp, TRUSTED_OPERATION)
        return Future(CallMeta(drt, Any, opeffects, DeclaredResultInfo(drt)))
    end
'''+s[j:]; wr(P,s)
P='Compiler/src/stmtinfo.jl'
s=rd(P); i=s.index('"""\n    info::SplitCallInfo <: CallInfo'); j=s.index("getresult_impl(info::SplitCallInfo, idx::Int) = getresult(info.info, idx)\n", i)+len("getresult_impl(info::SplitCallInfo, idx::Int) = getresult(info.info, idx)\n")
if s[j:j+1]=='\n': j+=1
s=s[:i]+s[j:]; wr(P,s)
for f in ['Compiler/src/Compiler.jl','base/Base.jl','src/staticdata.c','src/gc-stock.c','src/gc-mmtk.c']:
    wr(f, git('show',B+':'+f))
for f in ['Compiler/src/splittable.jl','base/splittable.jl','base/splittarget.jl']:
    subprocess.run(['git','rm','-q',f],check=True)
sub('src/julia_internal.h', "extern jl_genericmemory_t *jl_set_candidates JL_GLOBALLY_ROOTED; // the sets' candidates (datatype.c)\nextern jl_value_t *jl_split_table_miss_func JL_GLOBALLY_ROOTED; // the split tables' miss (gf.c)\n", "")
s=rd('src/gf.c'); i=s.index("// The table of a call's targets"); j=s.index("    return jl_unbox_voidpointer(fp);\n}\n", i)+len("    return jl_unbox_voidpointer(fp);\n}\n")
if s[j:j+1]=='\n': j+=1
s=s[:i]+s[j:]; wr('src/gf.c', s)
d='src/datatype.c'
wr(d, git('show',B+':'+d))
