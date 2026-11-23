#!/usr/bin/env python3
# The closed build's part (T16 of the traits series) cut in three, backwards from its tree:
#   c: the check in a session and the verifier (T16's tree, with `method_table` reading the check's overlay)
#   b: c without the check and the verifier: the closed splits
#   a: b without the splits: the members by use and the build's rounds
# Writes the three trees' versions of the files T16 changes to <out>/{a,b,c}/ and the patches
# <out>/t16{a,b,c}.patch (a on S3, b on a, c on b).
#     python3 k-t16-cut.py <julia-tree> <S3-rev> <T16-rev> <out>
import os, re, subprocess, sys

tree, s3, t16, out = sys.argv[1:5]
FILES = ['Compiler/src/abstractinterpretation.jl', 'Compiler/src/facts.jl', 'Compiler/src/precompile.jl',
         'Compiler/src/ssair/inlining.jl', 'Compiler/src/stmtinfo.jl', 'Compiler/src/typeinfer.jl',
         'Compiler/src/types.jl', 'Compiler/src/verifytrim.jl', 'src/datatype.c']

def show(rev, f):
    return subprocess.run(['git', 'show', f'{rev}:{f}'], cwd=tree, text=True, capture_output=True, check=True).stdout

def rep(s, a, b, count=1, name=''):
    n = s.count(a)
    if n != count:
        raise SystemExit(f"{name}: expected {count} of {a[:120]!r}, found {n}")
    return s.replace(a, b)

def remove_def(s, name, name_desc=''):
    """Remove a top-level Julia definition with the comment lines right above it."""
    lines = s.split('\n')
    pat = re.compile(r'^(function ' + re.escape(name) + r'\(|const ' + re.escape(name) + r'\b|' +
                     re.escape(name) + r'\(.*\) =)')
    idx = [i for i, l in enumerate(lines) if pat.match(l)]
    if len(idx) != 1:
        raise SystemExit(f"remove_def {name}: {len(idx)} definitions")
    i = idx[0]
    start = i
    while start > 0 and lines[start - 1].startswith('#'):
        start -= 1
    if lines[i].startswith('function '):
        j = i
        while lines[j] != 'end':
            j += 1
    else:
        j = i
        while j + 1 < len(lines) and lines[j + 1].startswith('    '):
            j += 1
    end = j + 1
    if end < len(lines) and lines[end] == '' and (start == 0 or lines[start - 1] == ''):
        end += 1
    return '\n'.join(lines[:start] + lines[end:])

c = {f: show(t16, f) for f in FILES}
s3f = {f: show(s3, f) for f in FILES}

# ---- c: T16's tree, with the overlay read by `method_table`; the comments T16 changed for no reason of its own
# keep S3's text
f = 'Compiler/src/types.jl'
c[f] = rep(c[f], "method_table(interp::NativeInterpreter) = interp.method_table\n",
           "function method_table(interp::NativeInterpreter)\n    ot = interp.overlay_table\n"
           "    return ot === nothing ? interp.method_table : ot\nend\n", name='overlay')
c[f] = rep(c[f], "    # whether calls are inferred only at facts\n", "    # whether calls are inferred only at facts (facts.jl)\n")
c[f] = rep(c[f], "# the policy of the code an interpreter makes and looks up under Julia's own owner: 0\n# plain, 1 facts, -1 the policy the runtime reaches a method with\n",
           "# the policy of the code an interpreter makes and looks up under Julia's own owner: 0 plain,\n# 1 facts, -1 the policy the runtime reaches a method with\n")
f = 'Compiler/src/typeinfer.jl'
c[f] = rep(c[f], "        # (also the code of a closed build's check, : the native interpreter's, under its own owner)\n",
           "        # (also the code of a closed build's check: the native interpreter's, under an owner of its own)\n")
c[f] = rep(c[f], "# hold its code inlined, are inferred again too, and so on up. A caller kept over an equal result (the\n# code slot) would go on invoking the instance with the fewer members.",
           "# hold its code inlined, are inferred again too, and so on up. A caller kept over an equal result would\n# go on invoking the instance with the fewer members.")
f = 'Compiler/src/abstractinterpretation.jl'
c[f] = rep(c[f], "# A closed build's call at a value known only by its trait, with no member of the value's type (compiler\n# ): a \"no method\" fact.",
           "# A closed build's call at a value known only by its trait, with no member of the value's type: a \"no\n# method\" fact.")
c[f] = rep(c[f], "        # (a closed build infers the call of a function known only by its signature,\n        # : it branches over the signature's members)\n",
           "        # (a closed build infers the call of a function known only by its signature: it branches over\n        # the signature's members)\n")
f = 'src/datatype.c'
c[f] = rep(c[f], "// the set's candidates now, in declaration order (a list never mutated; empty where none)\n// Whether a set's members can be listed (compiler §7.6): an open set",
           "// Whether a set's members can be listed: an open set")
c[f] = rep(c[f], "// The member patterns of a set's entries in force (compiler §7.6), but the set's own box entry:",
           "// The member patterns of a set's entries in force, but the set's own box entry:")
c[f] = rep(c[f], "        register_candidate(((jl_datatype_t*)uw)->name, T);\n}\n\n// Whether a set's members can be listed",
           "        register_candidate(((jl_datatype_t*)uw)->name, T);\n}\n\n// Whether a set's members can be listed")
c[f] = rep(c[f], "    JL_GC_POP();\n    return (jl_value_t*)out;\n}\n\nJL_DLLEXPORT jl_value_t *jl_candidates_of(jl_value_t *set)",
           "    JL_GC_POP();\n    return (jl_value_t*)out;\n}\n\n// the set's candidates now, in declaration order (a list never mutated; empty where none)\nJL_DLLEXPORT jl_value_t *jl_candidates_of(jl_value_t *set)")

# ---- b: c without the check in a session and the verifier
b = dict(c)
for f in ['Compiler/src/types.jl', 'Compiler/src/facts.jl', 'Compiler/src/verifytrim.jl']:
    b[f] = s3f[f]
f = 'Compiler/src/abstractinterpretation.jl'
b[f] = rep(b[f], "closed_build(interp::NativeInterpreter) = interp.closed !== nothing || closed_build()\n", "")
b[f] = rep(b[f], "closed_process(interp::NativeInterpreter) = interp.closed !== nothing || closed_process()\n", "")
b[f] = rep(b[f], "# inference by a closed build's rules: in a build, and in the build's check run in a session\n",
           "# inference by a closed build's rules\n")
f = 'Compiler/src/typeinfer.jl'
t = b[f]
t = rep(t, "    if code.owner === nothing || (interp isa NativeInterpreter && code.owner === cache_owner(interp))\n        # (also the code of a closed build's check: the native interpreter's, under an owner of its own)\n",
        "    if code.owner === nothing\n")
t = rep(t, "    interp::Union{AbstractInterpreter,Nothing}\n    # per method, the instances queued because an invoke names them and not their code (`collectinvokes!`)\n    named::IdDict{Any,Int}\n",
        "    interp::Union{AbstractInterpreter,Nothing}\n")
t = rep(t, ") = new(QueueItems[], IdSet{QueueItems}(), interp, IdDict{Any,Int}())", ") = new(QueueItems[], IdSet{QueueItems}(), interp)")
t = rep(t, ") = new(empty!(queue.tocompile), empty!(queue.inspected), interp, empty!(queue.named))", ") = new(empty!(queue.tocompile), empty!(queue.inspected), interp)")
t = rep(t, "end\n# An invoke that names its instance is followed for at most this many instances of one method: a call\n# that inference limited (a recursion over growing types) names a new instance at each step\nconst MAX_NAMED_INSTANCES = 4\n", "end\n")
t = rep(t, "                         external_linkage::Bool = false,\n                         instances::Bool = false)\n", "                         external_linkage::Bool = false)\n")
i0 = t.index("            elseif instances && edge isa MethodInstance\n")
i1 = t.index("            end\n        end\n        if invokelatest_queue !== nothing && isexpr(stmt, :invoke)", i0)
t = t[:i0] + t[i1:]
t = rep(t, "collectinvokes!(workqueue, src, sptypes; invokelatest_queue, external_linkage, instances = true)",
        "collectinvokes!(workqueue, src, sptypes; invokelatest_queue, external_linkage)")
i0 = t.index('"""\n    closed_check(mis::Vector{Any}, world::UInt, overlay = nothing)')
i1 = t.index("const _verify_trim_world_age = RefValue{UInt}(typemax(UInt))")
t = t[:i0] + t[i1:]
b[f] = t

# ---- a: b without the closed splits
a = dict(b)
f = 'Compiler/src/abstractinterpretation.jl'
t = a[f]
for name in ['closed_wrapper_set', 'closed_wrapper_of', 'closed_wrapper_bits', 'closed_member_type', 'closed_sparam_bits',
             'closed_choice_bits', 'closed_choosing_type', 'closed_has_set_argument', 'closed_kept_unions',
             'CLOSED_FORWARDERS', 'closed_is_forwarder', 'closed_forwarder', 'closed_forwarder_call',
             'closed_member_split', 'closed_callable_split', 'is_trait_arg_type']:
    t = remove_def(t, name)
t = rep(t, "                                  max_union_splitting::Int = InferenceParams(interp).max_union_splitting,\n                                  operation::Bool = true, member_split::Bool = true,\n                                  @nospecialize(closed_bound = nothing))",
        "                                  max_union_splitting::Int = InferenceParams(interp).max_union_splitting,\n                                  operation::Bool = true)")
i0 = t.index("    # (a closed build lists the methods a call at a value known only by its trait takes, up to the\n")
i1 = t.index("    matches = find_method_matches(interp, argtypes, atype; max_methods, max_union_splitting)", i0)
t = t[:i0] + t[i1:]
t = rep(t, "    # (in a closed build, a call at a value known only by its trait is one a later member may resolve)\n    closed_process(interp) && closed_has_set_argument(argtypes) && note_closed_operation!(sv)\n", "")
i0 = t.index("    # a closed build: a call whose method's static parameter a value known only by its\n")
i1 = t.index("            ssplit === nothing || return ssplit\n        end\n    end\n", i0) + len("            ssplit === nothing || return ssplit\n        end\n    end\n")
t = t[:i0] + t[i1:]
t = rep(t, "    state = CallInferenceState(func, matches)\n    # a closed split over a set's members: whether every branch returns the wrapper of a\n    # member, `closed_bound`\n    inbound = RefValue(true)\n",
        "    state = CallInferenceState(func, matches)\n")
t = rep(t, "                closed_bound === nothing || widenconst(ignorelimited(this_rt)) <: closed_bound || (inbound[] = false)\n", "")
i0 = t.index("            # a closed split whose branches each return the wrapper of a member of `X`: the join of more\n")
i1 = t.index("            end\n", t.index("state.rettype = typeintersect(state.rettype, closed_bound)", i0)) + len("            end\n")
t = t[:i0] + t[i1:]
t = rep(t, "        # (a closed build infers the call of a function known only by its signature: it branches over\n        # the signature's members)\n        if (!isconcretetype(aftw) || (aftw <: Builtin)) && !(closed_build(interp) && callable_set_type(aftw))\n",
        "        if !isconcretetype(aftw) || (aftw <: Builtin)\n")
t = rep(t, "        # (in a closed build, a call a later member may resolve: inferred again when the members grow)\n        closed_process(interp) && note_closed_operation!(sv)\n        # its arguments must be of `A`",
        "        # its arguments must be of `A`")
i0 = t.index("        # a closed build: the call branches over the signature's members, as an\n")
i1 = t.index("            csplit === nothing || return csplit\n        end\n", i0) + len("            csplit === nothing || return csplit\n        end\n")
t = t[:i0] + t[i1:]
i0 = t.index("    # a call of a function known only as `Callable`, with no signature (an element of a `Vector{Callable}`):\n")
i1 = t.index("            csplit === nothing || return csplit\n        end\n    end\n", i0) + len("            csplit === nothing || return csplit\n        end\n    end\n")
t = t[:i0] + t[i1:]
a[f] = t
f = 'Compiler/src/ssair/inlining.jl'
t = a[f]
i0 = t.index('"""\nWhether a signature knows each argument\'s type but at arguments known only by their trait')
i1 = t.index("function compileable_specialization(", i0)
t = t[:i0] + t[i1:]
t = rep(t, "        # a closed build: a call that does not know its argument's member runs the\n        # method's instance at the argument's type, the set; the instance's operations branch over the\n        # members. A session leaves such a call to dispatch when it runs.\n        new_atype = closed_build(state.interp) && closed_set_signature(atype, sparams) ? atype :\n                    get_compileable_sig(method, atype, sparams)\n",
        "        new_atype = get_compileable_sig(method, atype, sparams)\n")
t = rep(t, "    # an operation's split: never fully covered, its branches asserted; a `Callable`'s (a closed\n    # build's) checked as the box's call checks\n",
        "    # an operation's split: never fully covered, its branches asserted\n")
t = rep(t, "    kind = split && callable_set_type(widenconst(sig.ft)) ? IR_FLAG_TRUSTED_CALLABLE : UInt32(0)\n", "    kind = UInt32(0)\n")
a[f] = t

for name, files in (('a', a), ('b', b), ('c', c)):
    for f, txt in files.items():
        p = os.path.join(out, name, f)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'w').write(txt)
for f in FILES:
    p = os.path.join(out, 's3', f)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w').write(s3f[f])

def mkpatch(x, y, name):
    r = subprocess.run(['git', 'diff', '--no-index', '--no-prefix', x, y], cwd=out, text=True, capture_output=True)
    s = r.stdout
    s = re.sub(r'^diff --git ' + x + r'/(\S+) ' + y + r'/\S+', r'diff --git a/\1 b/\1', s, flags=re.M)
    s = re.sub(r'^--- ' + x + '/', '--- a/', s, flags=re.M)
    s = re.sub(r'^\+\+\+ ' + y + '/', '+++ b/', s, flags=re.M)
    s = re.sub(r'^index .*\n', '', s, flags=re.M)
    open(os.path.join(out, name), 'w').write(s)
mkpatch('s3', 'a', 't16a.patch')
mkpatch('a', 'b', 't16b.patch')
mkpatch('b', 'c', 't16c.patch')
print('ok')
