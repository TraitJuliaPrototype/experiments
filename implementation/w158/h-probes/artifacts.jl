# Open issue 251: the probes of the pattern (g-probes/artifacts.jl, P1 to P10) and more (P8 at a trait, P11 to P14,
# the controls S1 to S5), each read under every candidate reading of `readings.jl`. Run from the library's worktree:
#     $JN --project=. $W158/h-probes/artifacts.jl
using TraitWorld
println("TraitWorld at ", pathof(TraitWorld), "  commit ", readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) log -1 --format=%h`))
include(joinpath(@__DIR__, "readings.jl"))
using .Readings: READINGS, all_readings, verdict

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
# --- added for open issue 251 (h-probes) ---
# P8 control: a function with a method at the trait itself
gy(y::Y) = yv(y)
p8_trait(t::X) = gy(xy(t))
# P11: a closure that captures the box, called inside Base's code
p11_closure(t::X) = map(i -> sum(t), 1:2)
# P12: an error path whose message reaches a call with no method
p12_errnomethod(t::X) = xv(t) > 0 ? 1.0 : error("x", sum(t))
# P13: a callee that throws for every argument (no method missing)
@noinline fail(x) = throw(ArgumentError("no"))
p13_fails(t::X) = fail(t)
# P14: a value known only by its trait asserted to one member
p14_assert_member(t::X) = (xy(t)::Circ).r
# S: the controls that must stay as they are under every reading
s1_sum(t::X) = sum(t)
s2_field(t::X) = t.nosuchfield
s3_ok(t::X) = xv(t) + 1.0
s4_generic(t::X) = (typeof(t), Ref(t), string("a", t), t == t, hash(t))
@noinline helper(t, k) = xv(t) * k
s5_helper(t::X) = helper(t, 2.0)
end

names_p = sort!([n for n in names(A; all = true) if occursin(r"^[ps]\d", string(n))]; by = s -> (string(s)[1] == 's', parse(Int, match(r"\d+", string(s)).match), string(s)))
rows = Tuple{Symbol, Vector{Pair{Symbol,Any}}}[]
for n in names_p
    f = getglobal(A, n)
    f isa Function || continue
    m = only(methods(f))
    rs = all_readings(m)
    push!(rows, (n, rs))
    println("\n== ", n)
    for (k, r) in rs
        println("   ", rpad(k, 5), rpad(verdict(r), 12), r isa Vector ? join(string.(r), "; ") : r === nothing ? "" : r)
    end
end
println("\n| Probe | ", join(first.(READINGS), " | "), " |")
println("|---|", repeat("---|", length(READINGS)))
for (n, rs) in rows
    println("| ", n, " | ", join([r isa Vector ? (isempty(r) ? "none" : "fault") : verdict(r) for (_, r) in rs], " | "), " |")
end
