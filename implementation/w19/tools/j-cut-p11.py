import sys, subprocess; sys.path.insert(0,'/tmp/claude-harvest/w19f/tools')
from ed import *
def git(*a): return subprocess.run(['git']+list(a),capture_output=True,text=True,check=True).stdout
B='98960887b3'
P='Compiler/src/ssair/inlining.jl'
sub(P, '''    fallback_rt::Any # an operation's split: its declared result, else nothing
    table::Any       # and the table of its last branch, or nothing for the dynamic call
    trusted::UInt32  # the call's `IR_FLAGS_TRUSTED`: the fallback's result is checked, and a case's at an
                     # instance of wider types; a `Callable`'s split: its check's kind
    UnionSplit(handled_all_cases::Bool, fully_covered::Bool, atype::DataType, cases::Vector{InliningCase},
               @nospecialize(fallback_rt = nothing), @nospecialize(table = nothing), trusted::UInt32 = UInt32(0)) =
        new(handled_all_cases, fully_covered, atype, cases, Int[], fallback_rt, table, trusted)''', '''    trusted::UInt32  # the call's `IR_FLAGS_TRUSTED`: the fallback's result is checked, and a case's at an
                     # instance of wider types
    UnionSplit(handled_all_cases::Bool, fully_covered::Bool, atype::DataType, cases::Vector{InliningCase},
               trusted::UInt32 = UInt32(0)) =
        new(handled_all_cases, fully_covered, atype, cases, Int[], trusted)''')
s=rd(P); i=s.index("    if !handled_all_cases && union_split.table !== nothing\n"); j=s.index("    end\n", s.index("    elseif !handled_all_cases\n", i))+8
s=s[:i]+"    !handled_all_cases && push!(from_bbs, length(state.new_cfg_blocks))\n"+s[j:]
i=s.index('"""\nThe table for the last branch of an operation\'s split at `sig`'); j=s.index('"""\n    ir_inline_unionsplit!', i)
s=s[:i]+s[j:]; wr(P,s)
sub(P, "(; handled_all_cases, fully_covered, atype, cases, bbs, fallback_rt, table, trusted) = union_split", "(; handled_all_cases, fully_covered, atype, cases, bbs, trusted) = union_split")
sub(P, '''        elseif isa(case, InvokeCase) && (bfp = split_branch_pointer(table, atype, mtype)) !== nothing
            # a split's branch not inlined: through the candidate's `:caller_world` pointer, with no edge
            p = insert_node_here!(compact, NewInstruction(bfp, Ptr{Cvoid}, line))
            val = split_table_call!(compact, argexprs′, table::SplitTable, p, line)
''', "")
sub(P, '''            # in an operation's split, the invoke is typed by its own result, not the declared one
            ityp = fallback_rt === nothing ? typ :
                   case.invoke isa CodeInstance ? (case.invoke::CodeInstance).rettype : Any
            val = insert_node_here!(compact, NewInstruction(invoke_stmt, ityp, case.info, line, flag))''', '''            val = insert_node_here!(compact, NewInstruction(invoke_stmt, typ, case.info, line, flag))''')
sub(P, "            if fallback_rt === nothing && trusted != 0 && widenconst(typ) !== Any\n                mi = case.invoke", "            if trusted != 0 && widenconst(typ) !== Any\n                mi = case.invoke")
sub(P, '''            if fallback_rt !== nothing && !⊑(optimizer_lattice(interp), argextype(val, compact), fallback_rt)
                # a case whose result is not known to be the declared result asserts it
                val = insert_node_here!(compact, NewInstruction(
                    trusted_result_check(val, fallback_rt, trusted, get_inference_world(interp)), fallback_rt, line))
            end
''', "")
s=rd(P); i=s.index("        if table !== nothing\n            # the split's last branch: the pointer for the value's type"); j=s.index("        push!(pn.edges, bb)\n        push!(pn.values, ssa)", i)
s=s[:i]+'''        if trusted != 0 && widenconst(typ) !== Any
            # a call whose type rests on a declared result its members' own code does not check: the
            # fallback is left to dispatch, its result checked
            ssa = insert_node_here!(compact, NewInstruction(stmt, Any, line))
            check = trusted_result_check(ssa, widenconst(typ), trusted, get_inference_world(interp))
            ssa = insert_node_here!(compact, NewInstruction(check, typ, line))
        else
            ssa = insert_node_here!(compact, NewInstruction(stmt, typ, line))
        end
'''+s[j:]; wr(P,s)
# handle_call!, handle_cases!: Julia's own
base=git('show',B+':'+P)
def fn(text, header):
    i=text.index(header); j=text.index('\nend\n', i)+5; return text[i:j]
s=rd(P)
for h in ["function handle_call!(todo::Vector{Pair{Int,Any}},", "function handle_cases!(todo::Vector{Pair{Int,Any}}, ir::IRCode, idx::Int, stmt::Expr,"]:
    s=s.replace(fn(s,h), fn(base,h))
# the split's helpers after handle_call!
i=s.index('"""\nWhether a split\'s branch may be inlined'); j=s.index('\nend\n', s.index('function split_case_edge!(', i))+5
# keep any non-split definitions between? remove only split_inline_leaf and split_case_edge!
seg=s[i:j]
print([l for l in seg.split('\n') if l.startswith('function')])
s=s[:i]+s[j:]
wr(P,s)
sub(P, "        # (an operation's split checks its own fallback)\n        info isa SplitCallInfo && (trusted = UInt32(0))\n", "")
sub(P, '''        if item isa UnionSplit && item.fallback_rt === nothing
            todo[end] = idx => UnionSplit(item.handled_all_cases, item.fully_covered, item.atype, item.cases,
                                          item.fallback_rt, item.table, trusted)''', '''        if item isa UnionSplit
            todo[end] = idx => UnionSplit(item.handled_all_cases, item.fully_covered, item.atype, item.cases,
                                          trusted)''')
