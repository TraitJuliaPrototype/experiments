# Open issue 130's case in NetworkDynamics' shape (ndport/pkgs/NetworkDynamics-ports, symbolicindexing.jl):
# a bounded constructor without keywords, `NWState(int::(IntegratorView, HasSystem))`, beside the untyped one with
# keywords, `NWState(thing; ufill, guess)`, and the two-argument inner constructor `NWState(thing, uflat::AbstractVector)`
# (open issue 128); and the same shape as a function, `nwstate`. Run: experiments/tools/jl --name w130 julia-1.13/julia --project=<TraitWorld> repro.jl
using TraitWorld
@trait_module module ND130
using TraitWorld
export NWState, Net, Integ
@trait IntegratorView begin
    ustate(i::Self)::Vector{Float64}
end
@trait HasSystem begin
    sysnet(i::Self)::Any
end
struct Net; n::Int; end
extract_nw(n::Net) = n
struct NWState{U,NW}
    nw::NW
    uflat::U
    function NWState(thing, uflat::AbstractVector)
        nw = extract_nw(thing)
        new{typeof(uflat),typeof(nw)}(nw, uflat)
    end
end
NWState(int::(IntegratorView, HasSystem)) = NWState(sysnet(int), ustate(int))
function NWState(thing; ufill = 0.0, guess = false)
    nw = extract_nw(thing)
    return NWState(nw, fill(guess ? -1.0 : ufill, nw.n))
end
# the same shape as a function
nwstate(int::(IntegratorView, HasSystem)) = NWState(sysnet(int), ustate(int))
nwstate(thing; ufill = 0.0, guess = false) = NWState(thing; ufill, guess)
nwstate(thing, uflat::AbstractVector) = NWState(thing, uflat)
struct Integ; nw::Net; u::Vector{Float64}; end
@implement IntegratorView Integ begin
    ustate(i::Integ) = i.u
end
@implement HasSystem Integ begin
    sysnet(i::Integ) = i.nw
end
end
using .ND130
nw = Net(2)
int = Integ(nw, [1.0, 2.0])
for (s, f) in (("NWState(int)", () -> NWState(int)), ("NWState(nw)", () -> NWState(nw)),
               ("NWState(nw; ufill = 3.0)", () -> NWState(nw; ufill = 3.0)), ("NWState(nw; guess = true)", () -> NWState(nw; guess = true)),
               ("NWState(nw, [5.0, 6.0])", () -> NWState(nw, [5.0, 6.0])),
               ("nwstate(int)", () -> ND130.nwstate(int)), ("nwstate(int; ufill = 3.0)", () -> ND130.nwstate(int; ufill = 3.0)),
               ("nwstate(nw)", () -> ND130.nwstate(nw)), ("nwstate(nw; guess = true)", () -> ND130.nwstate(nw; guess = true)),
               ("nwstate(nw, [5.0, 6.0])", () -> ND130.nwstate(nw, [5.0, 6.0])),
               ("nwstate(Dynamic{IntegratorView}(int))", () -> ND130.nwstate(Dynamic{ND130.IntegratorView}(int))),
               ("kwcall's methods at UnionAll", () -> [m for m in methods(Core.kwcall) if Base.unwrap_unionall(m.sig).parameters[3] in (UnionAll, DataType)]))
    r = try f() catch e; "ERROR " * first(split(sprint(showerror, e), '\n')) end
    println(s, " => ", r isa NWState ? (r.nw, r.uflat) : r)
end
