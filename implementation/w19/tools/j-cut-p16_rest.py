import sys, subprocess; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
P='Compiler/src/ssair/inlining.jl'
sub(P, "(a function of a type not concrete, more than `MAX_SPLIT_TABLE_ARGS` arguments, a closed build or its\ncheck).", "(a function of a type not concrete, more than `MAX_SPLIT_TABLE_ARGS` arguments).")
sub(P, "function split_fallback_table(sig::Signature, @nospecialize(rt), closed::Bool)\n    closed && return nothing\n", "function split_fallback_table(sig::Signature, @nospecialize(rt))\n")
s=rd(P); i=s.index('"""\nWhether a signature knows each argument\'s type but at arguments known only by their trait'); j=s.index("function compileable_specialization(", i)
s=s[:i]+s[j:]; wr(P,s)
s=rd(P); i=s.index("        # a closed build: a call that does not know its argument's member runs the"); j=s.index("                    get_compileable_sig(method, atype, sparams)\n", i)+len("                    get_compileable_sig(method, atype, sparams)\n")
print(repr(s[i:j])); s=s[:i]+"        new_atype = get_compileable_sig(method, atype, sparams)\n"+s[j:]; wr(P,s)
sub(P, "    if fallback_rt !== nothing && isempty(cases) && !((info::SplitCallInfo).closed && handled_all_cases)\n", "    if fallback_rt !== nothing && isempty(cases)\n")
sub(P, "split_fallback_table(sig, fallback_rt, closed_build(state.interp))", "split_fallback_table(sig, fallback_rt)")
sub(P, '''    # in a closed build the split is over every member: past its branches the call
    # raises the `MethodError`, and no call is left to dispatch when the program runs
    closed = split && (info::SplitCallInfo).closed && handled_all_cases
    handle_cases!(todo, ir, idx, stmt, atype, cases, fallback_rt === nothing ? handled_all_cases : closed,''', '''    handle_cases!(todo, ir, idx, stmt, atype, cases, fallback_rt === nothing ? handled_all_cases : false,''')
P='Compiler/src/stmtinfo.jl'
sub(P, '''struct SplitCallInfo <: CallInfo
    info::CallInfo
    rt::Any
    closed::Bool    # a closed build's split over every member of a set whose members can be listed
end
SplitCallInfo(info::CallInfo, @nospecialize(rt)) = SplitCallInfo(info, rt, false)
''', '''struct SplitCallInfo <: CallInfo
    info::CallInfo
    rt::Any
end
''')
# typeinfer.jl, types.jl, verifytrim.jl, precompile.jl: the part below's, with the parts kept that are not the closed build's
def git(*a): return subprocess.run(['git']+list(a),capture_output=True,text=True,check=True).stdout
for f in ['Compiler/src/verifytrim.jl','Compiler/src/precompile.jl']:
    wr(f, git('show','HEAD~1:'+f))
P='Compiler/src/facts.jl'
sub(P, "facts, interp.crossings + Int(nested), false, nothing, nothing)", "facts, interp.crossings + Int(nested), false)")
