# W-158: as withfields_closed.jl, first without the overlay of the build's replacements of Base (OVL = nothing), then
# with it (vre): whether the declared-name test folds. Run from the library's tree: $JN --project=. <this file>
using TraitWorld
const CC = Base.Compiler
@trait VPlaced begin
    x::Float64
end
mutable struct VA; x::Float64; end
mutable struct VB; name::String; x::Float64; end
mutable struct VC; x::Float64; k::Int; end
@implement VPlaced VA
@implement VPlaced VB
@implement VPlaced VC
vread(xs::Vector{Dynamic{VPlaced}}) = (s = 0.0; for d in xs; s += d.x; end; s)
vre(xs::Vector{Dynamic{VPlaced}}) = (n = 0; for d in xs; n += withfields(d; x = 0.5) isa Dynamic{VPlaced}; end; n)
vnudged(p::VPlaced) = withfields(p; x = p.x + 1.0)
vmain(xs::Vector{Dynamic{VPlaced}}) = sum(d -> vnudged(d).x, xs)
const OVL = Ref{Any}(nothing)
function raw(f, a)
    TraitWorld._build_base()
    w = Base.get_world_counter()
    sig = Base.signature_type(f, a)
    mi = CC.specialize_method(only(Base._methods_by_ftype(sig, 1, w))::Core.MethodMatch)
    errors, parents = CC.closed_check(Any[mi], w, OVL[])
    V = CC.TrimVerifier
    println("== ", f, ": ", length(errors), " errors")
    for (warn, e) in errors
        print(warn ? "  warn " : "  ERROR ", typeof(e).name.name, ": ")
        if e isa V.CallMissing
            println(e.desc, " :: ", sprint(io -> V.verify_print_stmt(io, e.codeinfo, e.sptypes, e.stmtidx)))
            for fr in V.verify_create_stackframes(e.codeinst, e.stmtidx, parents)[1:min(end, 8)]
                println("      at ", fr.func, " ", fr.file, ":", fr.line)
            end
        else
            println(e)
        end
    end
end
raw(vread, (Vector{Dynamic{VPlaced}},))
raw(vre, (Vector{Dynamic{VPlaced}},))
raw(vmain, (Vector{Dynamic{VPlaced}},))
println("---- with the overlay")
OVL[] = TraitWorld._build_base()
raw(vre, (Vector{Dynamic{VPlaced}},))
