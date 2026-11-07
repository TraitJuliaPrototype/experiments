# Gate (W-101; compiler §3.3; E-283 (1)): the synthetic cascade. A plain callee `D` is compiled again
# when a method `D` dispatches to is added. Its callers hold only result edges to it (each calls it by
# an `:invoke` typed by its result), so they are marked, not invalidated; their next call compares
# `D`'s new result with the one they used.
# - Equal result: the callers' CodeInstances are kept, valid again, and run the new `D`; code in the
#   old world runs the old one.
# - Different result: the callers are compiled again.
# For a plain caller, a facts caller (the module option), and callers loaded from a package image.
# Usage: julia slot_cascade.jl
using Test, InteractiveUtils

slotstat() = (marks = ccall(:jl_code_slot_stat, Csize_t, (Cint,), 0), kept = ccall(:jl_code_slot_stat, Csize_t, (Cint,), 1),
              final = ccall(:jl_code_slot_stat, Csize_t, (Cint,), 2), misses = ccall(:jl_code_slot_stat, Csize_t, (Cint,), 3))

function cis(f, T)
    mi = only(filter(mi -> mi.specTypes == T, collect(Base.specializations(only(methods(f))))))
    out = Core.CodeInstance[]
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci !== nothing
        push!(out, ci)
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    return out
end
isfactsci(ci) = (ci.flags & 0x20) != 0
valid(ci) = ci.max_world == typemax(UInt)
current(f, T; facts = false) =
    only(filter(ci -> valid(ci) && ci.invoke != C_NULL && isfactsci(ci) == facts && ci.owner === nothing, cis(f, T)))
resultedges(ci) = Base.Compiler.ci_result_edges(ci)

# a new function's first call through each of its slots misses once (an image's slots start empty)
module Fresh
@noinline g(x::Int) = x + 1
@noinline h(x::Int) = g(x) * 2
end
let m0 = slotstat().misses
    Fresh.h(1)
    @assert slotstat().misses > m0 "the call of `g` goes through a slot"
end

module M
E(x) = x + 1
@noinline D(x::Int) = E(x) + x
@noinline C(x::Int) = D(x) * 2
@noinline P(x::Int) = C(x) + 3
end

module FM
Base.Experimental.@compiler_options facts=true
import ..M
@noinline Cf(x::Int) = M.D(x) * 2
@noinline Pf(x::Int) = Cf(x) + 3
end

const TD = Tuple{typeof(M.D), Int}
const TC = Tuple{typeof(M.C), Int}
const TP = Tuple{typeof(M.P), Int}
const TCf = Tuple{typeof(FM.Cf), Int}
const TPf = Tuple{typeof(FM.Pf), Int}

@testset "the session" begin
    @test M.P(3) == 17 && FM.Pf(3) == 17
    w0 = Base.get_world_counter()
    cD, cC, cP = current(M.D, TD), current(M.C, TC), current(M.P, TP)
    cCf, cPf = current(FM.Cf, TCf; facts = true), current(FM.Pf, TPf; facts = true)
    Dmi = cD.def
    @test resultedges(cC) !== nothing && any(x -> x === Dmi, resultedges(cC))
    @test resultedges(cCf) !== nothing && any(x -> x === Dmi, resultedges(cCf))
    s0 = slotstat()

    # an equal result: the callers are kept
    @eval M E(x::Int) = x + 2
    @test !valid(cC) && !valid(cCf) && !valid(cD)
    s1 = slotstat()
    @test s1.marks - s0.marks >= 4                      # C, P, Cf, Pf
    @test M.P(3) == 19 && FM.Pf(3) == 19
    @test current(M.C, TC) === cC && current(M.P, TP) === cP
    @test current(FM.Cf, TCf; facts = true) === cCf && current(FM.Pf, TPf; facts = true) === cPf
    cD2 = current(M.D, TD)
    @test cD2 !== cD
    @test any(x -> x === cD2, cC.edges) && !any(x -> x === cD, cC.edges)
    s2 = slotstat()
    @test s2.kept - s1.kept >= 4
    @test Base.invoke_in_world(w0, M.P, 3) == 17 && Base.invoke_in_world(w0, FM.Pf, 3) == 17
    w1 = Base.get_world_counter()

    # a different result: the callers are compiled again
    @eval M E(x::Int) = 0.5
    @test M.P(3) == 10.0 && FM.Pf(3) == 10.0
    @test current(M.C, TC) !== cC && current(M.P, TP) !== cP
    @test current(FM.Cf, TCf; facts = true) !== cCf
    s3 = slotstat()
    @test s3.final > s2.final
    @test Base.invoke_in_world(w1, M.P, 3) == 19 && Base.invoke_in_world(w0, M.P, 3) == 17
    println("session: ", (marks = s3.marks - s0.marks, kept = s3.kept - s0.kept, final = s3.final - s0.final))
end

# a callee inlined at one site and called at another (the review of 2026-11-07, M2): the caller holds a
# code edge to it, so a recompilation to an equal result with other code compiles the caller again
module M2
E(x) = x + 1
D(x::Int) = E(x) + x
C(x::Int) = (@inline D(x)) + (@noinline D(x + 1))
end
@testset "inlined at one site, called at another" begin
    @test M2.C(3) == 16
    @eval M2 E(x::Int) = x + 2
    @test M2.C(3) == 18                                  # the inlined copy is not kept
end

# a cycle of result edges (the review, H2): X -> Y -> Z -> X, Z recompiled; revalidation inside
# inference terminates, and the results are the new ones
module R
E(x) = x + 1
@noinline Z(x::Int) = x > 0 ? X(x - 1) + E(x) : 0
@noinline Y(x::Int) = Z(x) * 1
@noinline X(x::Int) = Y(x) + 1
end
@testset "a cycle of result edges" begin
    @test R.X(3) == 13
    w = Base.get_world_counter()
    @eval R E(x::Int) = x + 2
    @test R.X(3) == 16
    @test Base.invoke_in_world(w, R.X, 3) == 13
end

# the same callers loaded from a package image
const root = mktempdir()
function package(name, uuid, deps, src)
    mkpath(joinpath(root, name, "src"))
    write(joinpath(root, name, "Project.toml"), "name = \"$name\"\nuuid = \"$uuid\"\n" *
        (isempty(deps) ? "" : "[deps]\n" * join(("$d = \"$u\"\n" for (d, u) in deps), "")))
    write(joinpath(root, name, "src", "$name.jl"), src)
end
const uD, uC = "d1d1d1d1-0000-4000-8000-0000000000d1", "c1c1c1c1-0000-4000-8000-0000000000c1"
package("SlotD", uD, [], """
module SlotD
E(x) = x + 1
@noinline D(x::Int) = E(x) + x
precompile(D, (Int,))
end
""")
package("SlotC", uC, [("SlotD", uD)], """
module SlotC
using SlotD
@noinline C(x::Int) = SlotD.D(x) * 2
@noinline P(x::Int) = C(x) + 3
precompile(P, (Int,))
end
""")
const env = joinpath(root, "env")
mkpath(env)
write(joinpath(env, "Project.toml"), "[deps]\nSlotC = \"$uC\"\nSlotD = \"$uD\"\n")
write(joinpath(env, "Manifest.toml"), """
julia_version = "$(VERSION)"
manifest_format = "2.0"
[[deps.SlotD]]
path = "$(joinpath(root, "SlotD"))"
uuid = "$uD"
version = "0.0.0"
[[deps.SlotC]]
deps = ["SlotD"]
path = "$(joinpath(root, "SlotC"))"
uuid = "$uC"
version = "0.0.0"
""")
const probe = """
using SlotC, SlotD
function cis(f, T)
    mi = only(filter(mi -> mi.specTypes == T, collect(Base.specializations(only(methods(f))))))
    out = Core.CodeInstance[]; ci = mi.cache
    while true; push!(out, ci); isdefined(ci, :next) || break; ci = ci.next; end
    out
end
current(f, T) = only(filter(ci -> ci.max_world == typemax(UInt) && ci.invoke != C_NULL && ci.owner === nothing, cis(f, T)))
TC = Tuple{typeof(SlotC.C), Int}
println("first: ", SlotC.P(3))
cC = current(SlotC.C, TC)
println("from image: ", (cC.flags & 0x04) != 0, " record: ", Base.Compiler.ci_result_edges(cC) !== nothing)
@eval SlotD E(x::Int) = x + 2
println("after: ", SlotC.P(3))
println("kept: ", current(SlotC.C, TC) === cC)
"""
@testset "a package image" begin
    cmd = addenv(`$(Base.julia_cmd()) --startup-file=no --project=$env -e $probe`,
                 "JULIA_DEPOT_PATH" => joinpath(root, "depot") * ":")
    out = IOBuffer()
    p = run(pipeline(ignorestatus(cmd), stdout = out, stderr = out))
    s = String(take!(out))
    println(replace(s, "\n" => " | "))
    @test success(p)
    @test occursin("first: 17", s) && occursin("after: 19", s)
    @test occursin("from image: true record: true", s)
    @test occursin("kept: true", s)
end
println("slot_cascade: done")
