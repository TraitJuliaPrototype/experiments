#!/bin/bash
# E-255 (U7): make the counting Compiler: a fresh copy of julia-1.13/Compiler with u7count.jl included and
# the negative folds' sites routed through it. Run from anywhere; writes experiments/w83/u7/Compiler.
set -eu
U7=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$U7/../../.." && pwd)
rm -rf "$U7/Compiler"
cp -r "$ROOT/julia-1.13/Compiler" "$U7/Compiler"
rm -rf "$U7/Compiler/test"
S="$U7/Compiler/src"
cp "$U7/u7count.jl" "$S/u7count.jl"
python3 -I - "$S" <<'EOF'
import re, sys
S = sys.argv[1]
def rd(f): return open(f"{S}/{f}").read()
def wr(f, s): open(f"{S}/{f}", "w").write(s)
def sub1(s, old, new, f):
    assert s.count(old) == 1, (f, old, s.count(old))
    return s.replace(old, new)

# 1. include the counters
f = "Compiler.jl"; s = rd(f)
s = sub1(s, 'include("inferencestate.jl")\n', 'include("inferencestate.jl")\ninclude("u7count.jl")\n', f)
wr(f, s)

# 2. isa_tfunc and subtype_tfunc: each Const(false) recorded (not `isa(x, Union{})`)
f = "tfuncs.jl"; s = rd(f)
i0 = s.index("@nospecs function isa_tfunc(")
i1 = s.index("add_tfunc(<:, 2, 2, subtype_tfunc, 10)")
blk = s[i0:i1]
blk = sub1(blk, """            if isa(v, Const) || isa(v, Conditional)
                # this and the `isdispatchelem` below test for knowledge of a
                # leaftype appearing on the LHS (ensuring the isa is precise)
                return Const(false)""", """            if isa(v, Const) || isa(v, Conditional)
                # this and the `isdispatchelem` below test for knowledge of a
                # leaftype appearing on the LHS (ensuring the isa is precise)
                return _u7f("isa:const", widenconst(v), t)""", f)
blk = sub1(blk, "isdispatchelem(v) && return Const(false)", 'isdispatchelem(v) && return _u7f("isa:leaf", v, t)', f)
blk = sub1(blk, """                if !iskindtype(v)
                    return Const(false)""", """                if !iskindtype(v)
                    return _u7f("isa:disjoint", v, t)""", f)
blk = sub1(blk, """            if isexact_a || (b !== Bottom && !hasintersect(a, b))
                return Const(false)""", """            if isexact_a || (b !== Bottom && !hasintersect(a, b))
                return _u7f(isexact_a ? "subtype:exact" : "subtype:disjoint", a, b)""", f)
s = s[:i0] + blk.replace("hasintersect(", "hasintersect(") + s[i1:]
wr(f, s)
SKIP_TF = (i0, i0 + len(blk))   # these lines are not rewritten below

# 3. tmeet of a constant that is not an instance
f = "typelattice.jl"; s = rd(f)
s = sub1(s, """        if !has_free_typevars(t) && !isa(v.val, t)
            return Bottom""", """        if !has_free_typevars(t) && !isa(v.val, t)
            U7_ON[] && _u7_neg("tmeet:const", typeof(v.val), t)
            return Bottom""", f)
wr(f, s)

# 4. typeintersect / hasintersect at the call sites in Compiler's own files
for f in ["abstractinterpretation.jl", "abstractlattice.jl", "tfuncs.jl", "typelattice.jl",
          "typelimits.jl", "facts.jl", "ssair/passes.jl"]:
    s = rd(f)
    if f == "tfuncs.jl":
        a = s.index("@nospecs function isa_tfunc("); b = s.index("add_tfunc(<:, 2, 2, subtype_tfunc, 10)")
        skip = (s.count("\n", 0, a) + 1, s.count("\n", 0, b) + 1)
    else:
        skip = (0, -1)
    out = []
    for n, line in enumerate(s.split("\n"), 1):
        st = line.lstrip()
        if not (st.startswith("#") or "using " in line or "import " in line or skip[0] <= n <= skip[1]):
            tag = f.split("/")[-1].replace(".jl", "")
            line = re.sub(r'(?<![\w.])typeintersect\(', f'_u7ti("{tag}:{n}", ', line)
            line = re.sub(r'(?<![\w.])hasintersect\(', f'_u7hi("{tag}:{n}", ', line)
        out.append(line)
    wr(f, "\n".join(out))

# 5. the code being compiled, for the record
f = "abstractinterpretation.jl"; s = rd(f)
s = sub1(s, """    @assert !is_inferred(frame)
    W = frame.ip""", """    @assert !is_inferred(frame)
    U7_FRAME[] = frame
    W = frame.ip""", f)
s = sub1(s, """            currpc += 1
            frame.currpc = currpc
""", """            currpc += 1
            frame.currpc = currpc
            U7_FRAME[] = frame
""", f)
s = sub1(s, """    result::Union{Nothing,Future{RTEffects}}=nothing)
    rt = nothing
""", """    result::Union{Nothing,Future{RTEffects}}=nothing)
    U7_FRAME[] = frame
    rt = nothing
""", f)
wr(f, s)
f = "optimize.jl"; s = rd(f)
s = sub1(s, """function optimize(interp::AbstractInterpreter, opt::OptimizationState, caller::InferenceResult)
""", """function optimize(interp::AbstractInterpreter, opt::OptimizationState, caller::InferenceResult)
    U7_FRAME[] = opt
""", f)
wr(f, s)
f = "ssair/irinterp.jl"; s = rd(f)
s = sub1(s, """    (; ir, tpdum, ssa_refined) = irsv
""", """    (; ir, tpdum, ssa_refined) = irsv
    U7_FRAME[] = irsv
""", f)
wr(f, s)
EOF
cd "$U7" && diff -ru "$ROOT/julia-1.13/Compiler/src" Compiler/src > compiler.patch || true
echo "patched: $(grep -c '^+' "$U7/compiler.patch") added lines; sites: $(grep -o '_u7[th]i("[^"]*"' -r "$S" | wc -l)"
