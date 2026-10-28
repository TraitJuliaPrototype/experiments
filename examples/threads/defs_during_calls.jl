# E-63 (W-9): trait objects and Dynamic values across threads while the main thread defines. Worker threads
# call bounded functions on Dynamic values and through `compiled_for` in a loop; meanwhile the main thread
# declares new types with implementations and redefines one implementation's operation. Expected: every
# result a worker computes is a value the method table gave at some world (the old or the new method,
# never a mix or garbage), no crash, and after the definitions every worker sees the new methods.
#     julia -t 4 --project=env threads/defs_during_calls.jl
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld
Threads.nthreads() >= 2 || error("run with -t 4")
@trait_module module DM
using TraitWorld
export DS, darea, dtotal, dtwice
@trait DS begin
    darea(s::DS)::Float64
end
dtotal(v::Vector{Dynamic{DS}}) = (s = 0.0; for d in v; s += darea(d); end; s)
dtwice(s::DS) = 2 * darea(s)
end
const N0 = 8
let io = IOBuffer()
    for i in 1:N0
        println(io, "struct D$i; a::Float64; end")
        println(io, "TraitWorld.@implement DM.DS D$i begin darea(s) = $(Float64(i)) * s.a end")
    end
    include_string(Main, String(take!(io)), "defs0.jl")
end
const TYPES0 = [getglobal(Main, Symbol(:D, i)) for i in 1:N0]
const STOP = Threads.Atomic{Bool}(false)
const BAD = Threads.Atomic{Int}(0)
const CALLS = Threads.Atomic{Int}(0)
# D1's operation is redefined from `1.0 * a` to `100.0 * a` while workers run: a sum over D1..D8 is
# either the old total (36) or the new one (36 - 1 + 100 = 135)
const OLD = sum(Float64.(1:N0)); const NEW = OLD - 1.0 + 100.0
ucall(v::Vector{Any}) = (s = 0.0; for x in v; s += DM.dtwice(compiled_for(x))::Float64; end; s)
function worker(k)
    vd = Dynamic{DM.DS}[Dynamic{DM.DS}(T(1.0)) for T in circshift(TYPES0, k)]
    va = Any[T(1.0) for T in circshift(TYPES0, k)]
    while !STOP[]
        a = Base.invokelatest(DM.dtotal, vd)
        b = Base.invokelatest(ucall, va)
        (a in (OLD, NEW) && b in (2OLD, 2NEW)) || Threads.atomic_add!(BAD, 1)
        Threads.atomic_add!(CALLS, 1)
    end
end
tasks = [Threads.@spawn worker(k) for k in 1:max(2, Threads.nthreads() - 1)]
sleep(0.5)
# the main thread defines while the workers call: new types with implementations, then the redefinition
let io = IOBuffer()
    for i in N0+1:N0+16
        println(io, "struct D$i; a::Float64; end")
        println(io, "TraitWorld.@implement DM.DS D$i begin darea(s) = $(Float64(i)) * s.a end")
    end
    include_string(Main, String(take!(io)), "defs1.jl")
end
sleep(0.3)
Core.eval(Main, :(DM.darea(s::D1) = 100.0 * s.a))
sleep(0.5)
STOP[] = true
foreach(wait, tasks)
check("no worker computed a value outside the old and new method tables ($(CALLS[]) calls)", BAD[] == 0 && CALLS[] > 0)
newtypes = [getglobal(Main, Symbol(:D, i)) for i in N0+1:N0+16]
check("after the definitions, the new types work from another thread",
      fetch(Threads.@spawn Base.invokelatest(DM.dtotal, Dynamic{DM.DS}[Dynamic{DM.DS}(T(1.0)) for T in newtypes])) == sum(Float64.(N0+1:N0+16)))
check("the redefinition is seen by every thread",
      all(==(200.0), fetch.([Threads.@spawn Base.invokelatest(DM.dtwice, compiled_for(Main.D1(1.0))) for _ in 1:4])))
summary()
