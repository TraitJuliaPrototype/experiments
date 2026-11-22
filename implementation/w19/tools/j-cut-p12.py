import sys, subprocess; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
def git(*a): return subprocess.run(['git']+list(a),capture_output=True,text=True,check=True).stdout
B='98960887b3'
P='Compiler/src/abstractinterpretation.jl'
s=rd(P); i=s.index("    # a call of a value known as a `Callable{A, S}`: its result is `S`, asserted. A\n"); j=s.index("    if hasintersect(wft, Builtin)\n", i)
s=s[:i]+s[j:]
i=s.index("# A `Callable{A, S}`'s call: its result `S` is checked in the code that calls"); j=s.index("# call where the function is any lattice element", i)
s=s[:i]+s[j:]; wr(P,s)
P='Compiler/src/ssair/inlining.jl'
sub(P, "        if isa(info, CallableCallInfo)\n            handle_callable_call!(ir, idx, stmt, info, state)\n            continue\n        end\n", "")
s=rd(P); i=s.index("# A call of a value known as `Callable{A, S}`: its arguments checked against `A`"); j=s.index("function linear_inline_eligible(", i)
s=s[:i]+s[j:]; wr(P,s)
s=rd(P); i=s.index("# The check of a result `val` against `T`: for a `Callable{A, S}`'s, the box's `TypeError`,"); j=s.index("# An operation's call at a receiver typed by its set, or a `Callable`'s: the", i)
s=s[:i]+'''# The check of a result `val` against `T`: `typeassert`'s, as the operation's own call asserts
trusted_result_check(@nospecialize(val), @nospecialize(T), trusted::UInt32, world::UInt) =
    Expr(:call, GlobalRef(Core, :typeassert), val, T)

'''+s[j:]
s=s.replace("# An operation's call at a receiver typed by its set, or a `Callable`'s: the\n# dynamic call,","# An operation's call at a receiver typed by its set: the\n# dynamic call,")
wr(P,s)
P='Compiler/src/stmtinfo.jl'
s=rd(P); i=s.index('"""\n    info::CallableCallInfo <: CallInfo'); j=s.index('"""\n    info::SplitCallInfo <: CallInfo', i)
s=s[:i]+s[j:]; wr(P,s)
P='base/boot.jl'
s=rd(P); i=s.index("# `Callable{A, S}`: the functions called with arguments of `A`, returning an `S`."); j=s.index("abstract type Callable{A<:Tuple, S} end\n\n", i)+len("abstract type Callable{A<:Tuple, S} end\n\n")
s=s[:i]+s[j:]
i=s.index("# a call of a value known as `Callable{A, S}`: its arguments are of `A`, or the call"); j=s.index("struct UndefKeywordError <: Exception", i)
s=s[:i]+s[j:]; wr(P,s)
P='base/Base.jl'
sub(P, "# `Callable{A, S}`: every function is a member of every instance, by one entry whose instance,\n# `Callable` itself, leaves both inputs free; a callable type that is no `Function` joins by its own declaration\nccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any), Function, Core.Callable, Core, nothing, :self)\n", "")
for f in ['base/loading.jl','base/sysimg.jl','src/jl_exported_data.inc']:
    wr(f, git('show',B+':'+f))
s=rd('src/jltypes.c'); i=s.index("    // `Callable{A, S}`: a set from Core's build"); j=s.index("    }\n", i)+6
s=s[:i]+s[j:]; wr('src/jltypes.c', s)
sub('src/julia_internal.h', "JL_DLLEXPORT void jl_invalidate_code_instances_new_world(jl_svec_t *cis);\n", "")
