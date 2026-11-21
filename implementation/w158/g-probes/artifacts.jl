# The pattern of open issue 249: which statements of the optimized code at the box does the bounded check read as
# faults that the optimizer made, not the method as written? Each case is read by `check_at_box` (the optimized
# instance) and, where the library has `_box_faults`, by the same reading over the inferred code before
# optimization (no inlining, no split). Run from the library's worktree: $JN --project=. $W158/g-probes/artifacts.jl
using TraitWorld
println("TraitWorld at ", pathof(TraitWorld), "; _box_faults: ", isdefined(TraitWorld, :_box_faults))
const CC = TraitWorld.CC

module A
using TraitWorld
@trait_module bounded = false
struct Sol{T}; u::Vector{T}; end
@trait Y begin
    yv(y::Y)::Float64
end
@trait X begin
    xv(t::X)::Float64
    xs(t::X)::Sol                                   # a result of an abstract type
    xu(t::X)::Union{Int, Float64}                   # a union result
    xy(t::X)::Y                                     # a value known only by its trait
end
struct Circ; r::Float64; end
yv(c::Circ) = c.r
@implement Y Circ
struct M; end
xv(::M) = 1.0; xs(::M) = Sol([1.0]); xu(::M) = 1; xy(::M) = Circ(1.0)
@implement X M
# P1: the split's other branch: one method at a part of an abstract argument (open issue 249)
wsol(s::Sol{Float64}, t::X) = 1.0
p1_split(t::X) = wsol(xs(t), t)
# P2: a union split that its methods cover; and one that they cover in part
gu(x::Int, t::X) = 1.0
gu(x::Float64, t::X) = 2.0
p2_covered(t::X) = gu(xu(t), t)
gu1(x::Int, t::X) = 1.0
p2_part(t::X) = gu1(xu(t), t)
# P3: a callee's error path for other types, inlined or not
bad(t) = error("not supported: ", t)
@inline kk(x, t) = x isa Int ? 1.0 : bad(t)
@noinline kkn(x, t) = x isa Int ? 1.0 : bad(t)
p3_inlined(t::X) = kk(xu(t), t)
p3_not_inlined(t::X) = kkn(xu(t), t)
# P4: a callee with a call that finds no method on one branch, inlined or not
@inline g4(t, k::Int) = k > 0 ? xv(t) : sum(t)
@noinline g4n(t, k::Int) = k > 0 ? xv(t) : sum(t)
p4_inlined(t::X, k::Int) = g4(t, k)
p4_not_inlined(t::X, k::Int) = g4n(t, k)
# P5: a type assertion that fails at the box (a builtin)
p5_assert(t::X) = (t::M; 1.0)
# P6: the method's own error path that names the box
p6_error(t::X) = xv(t) > 0 ? xv(t) : error("negative: ", t)
p6_throw(t::X) = xv(t) > 0 ? xv(t) : throw(ArgumentError(string("negative: ", t)))
# P7: a branch that constant propagation removes, inlined or not
@inline g7(t, k::Int) = k == 1 ? xv(t) : sum(t)
@noinline g7n(t, k::Int) = k == 1 ? xv(t) : sum(t)
p7_inlined(t::X) = g7(t, 1)
p7_not_inlined(t::X) = g7n(t, 1)
# P8: a value known only by its trait passed to a function with a method for one member (one method: split; five: left to run time)
onlycirc(c::Circ) = c.r
p8_one(t::X) = onlycirc(xy(t))
struct C2; end; struct C3; end; struct C4; end; struct C5; end
five(c::Circ) = 1.0; five(c::C2) = 2.0; five(c::C3) = 3.0; five(c::C4) = 4.0; five(c::C5) = 5.0
p8_five(t::X) = five(xy(t))
# P9: a call whose result inference gives as Union{} only after inlining a callee that throws for the box's case
@inline thr(x) = x isa Float64 ? x : throw(ArgumentError("no"))
p9_throw_builtin(t::X) = thr(xu(t))
# P10, the control: an abstract argument that no method covers at all (the split's lookup finds none): a fault
gint(x::Int, t::X) = 1.0
p10_none(t::X) = gint(xs(t), t)
end

const KEYS = ("throw_methoderror", "(isa)", "unreachable", "typeassert", "error", "sum", "bad", "wsol", "gu", "kk", "g4", "g7", "onlycirc", "five", "thr", "gint", "throw")
w = Base.get_world_counter()
for n in sort!([n for n in names(A; all = true) if startswith(string(n), "p")]; by = string)
    f = getglobal(A, n)
    f isa Function || continue
    m = only(methods(f))
    sig = TraitWorld.box_signature(m)
    fs = TraitWorld.check_at_box(m)
    println("\n== ", n, ": optimized reading: ", fs === nothing ? "not read" : length(fs), " fault(s)")
    fs === nothing || foreach(u -> println("     ", u.kind, ": ", TraitWorld._fault_line(u)), fs)
    interp = CC.NativeInterpreter(w; facts = true)
    src = Base.code_typed_by_type(sig; interp, optimize = true)[1][1]
    for (i, st) in enumerate(src.code)
        s = sprint(show, st)
        any(k -> occursin(k, s), KEYS) && println("       %", i, " = ", s, " :: ", src.ssavaluetypes[i])
    end
    if isdefined(TraitWorld, :_box_faults)
        u = Base.code_typed_by_type(sig; interp, optimize = false)[1][1]
        fu = TraitWorld._box_faults(m, u, interp, w)
        println("   before optimization: ", length(fu), " fault(s)")
        foreach(x -> println("     ", x.kind, ": ", TraitWorld._fault_line(x)), fu)
    end
end
