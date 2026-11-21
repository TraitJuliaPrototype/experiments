# Open issue 249: the bounded check at the box and the optimizer's split. Run from the library's worktree:
#   $JN --project=. $W158/g-probes/split.jl
# Each method is read by `check_at_box`; the optimized code at the box is printed for the calls that matter.
using TraitWorld, InteractiveUtils
println("TraitWorld at ", pathof(TraitWorld))

module S
using TraitWorld
struct Sol{T}; u::Vector{T}; end
@trait Prob{T} begin
    @const u0::Vector{T}
end
@trait Alg begin
    run(a::Alg, x::Vector{Float64})::Sol                    # the result's type abstract: Sol, not Sol{Float64}
end
withprob(s::Sol{T}, p::Prob{T}) where {T} = (s.u, p.u0)
# case A (nl_with_problem): an argument of an abstract type whose one method covers part of it
caseA(p::Prob{Float64}, a::Alg) = withprob(run(a, p.u0), p)
# case B (solve_nonlinear in a keyword body at untyped keywords): a keyword of a type the code does not know
struct Opts; tol::Float64; end
inner(p::Prob{Float64}, a::Alg, o::Opts) = run(a, p.u0)
caseB(p::Prob{Float64}, a::Alg; tol = 1e-8) = inner(p, a, Opts(tol))
# the control: no method at the types the code knows (sum at a box reaches iterate, which has none)
ctrl1(p::Prob{Float64}) = sum(p)
# a direct call with no method at the box at all
nometh(x::Int) = x
ctrl2(p::Prob{Float64}) = nometh(p)
# a split on a value known only by its trait: one method covers some members
@trait Sh begin
    area(s::Sh)::Float64
end
@trait Holder begin
    shape(h::Holder)::Sh                                    # a value known only by its trait
end
struct Circle; r::Float64; end
area(c::Circle) = c.r
@implement Sh Circle
onlycircle(c::Circle) = c.r
caseC(h::Holder) = onlycircle(shape(h))                    # a method for one member of Sh only
caseD(h::Holder) = area(shape(h))                          # the operation: bounded
end

kwb = [getglobal(S, n) for n in names(S; all = true) if startswith(string(n), "#caseB#")]
for f in (S.caseA, S.caseB, kwb..., S.ctrl1, S.ctrl2, S.caseC, S.caseD)
    for m in methods(f)
        sig = TraitWorld.box_signature(m)
        sig === nothing && continue
        println("\n== ", m.sig, "\n   at ", sig)
        fs = TraitWorld.check_at_box(m)
        println("   faults: ", fs === nothing ? "not read" : length(fs))
        fs === nothing || foreach(u -> println("     ", u.kind, ": ", TraitWorld._fault_line(u)), fs)
        r = Base.code_typed_by_type(sig; optimize = true)
        if length(r) == 1
            src = r[1][1]
            for (i, st) in enumerate(src.code)
                s = sprint(show, st)
                (occursin("throw_methoderror", s) || occursin("isa", s) || occursin("withprob", s) || occursin("inner", s) ||
                 occursin("onlycircle", s) || occursin("unreachable", s) || occursin("typeassert", s)) &&
                    println("     %", i, " = ", s, " :: ", src.ssavaluetypes[i])
            end
        end
    end
end
