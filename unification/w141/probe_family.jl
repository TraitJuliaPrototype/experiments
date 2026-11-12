# E-367, stage 0 (W-141), R1 and R2: families of one trait, spelled Type{F{T}} where T, and the instance
# of a trait with inputs. Run: julia --startup-file=no probe_family.jl
function fam end
abstract type Col{T} end
w() = Base.get_world_counter()
look(sig) = Base._methods_by_ftype(sig, -1, w())
function step(lo, hi)
    t = @elapsed for i in lo:hi
        S = Symbol(:F, i)
        @eval struct $S{T} end
        @eval fam(::Type{Col{T}}, ::Type{$S{T}}) where {T} = nothing
    end
    F17 = Core.eval(Main, :F17)
    hit = Tuple{typeof(fam), Type{<:Col}, Type{F17{Int}}}; miss = Tuple{typeof(fam), Type{<:Col}, Type{Vector{Int}}}
    look(hit); look(miss)
    th = @elapsed for _ in 1:200; look(hit); end
    tm = @elapsed for _ in 1:200; look(miss); end
    m = look(hit)
    println("families ", lpad(hi, 5), ": insert ", round(t / (hi - lo + 1) * 1e6; digits = 0), " us each; lookup hit ",
            round(th / 200 * 1e6; digits = 1), " us, miss ", round(tm / 200 * 1e6; digits = 1), " us; instance ",
            length(m) == 1 ? m[1].sparams : length(m)); flush(stdout)
end
lo = 1
for hi in (250, 500, 1000, 2000)
    step(lo, hi); global lo = hi + 1
end
t = @elapsed ms = methods(fam)
println("methods(): ", length(ms), " in ", round(t * 1e3; digits = 1), " ms")
# fresh signatures each time (no cache of the lookup)
Fs = [Core.eval(Main, Symbol(:F, i)) for i in 1:2000]
t = @elapsed for F in Fs
    look(Tuple{typeof(fam), Type{<:Col}, Type{F{Float64}}})
end
println("2000 first lookups, one per family: ", round(t / 2000 * 1e6; digits = 1), " us each")
# the unmet-intersection edge's signature against 2000 methods
t = @elapsed r = look(Tuple{typeof(fam), Type{<:Col}, Type{<:AbstractVector}})
println("a lookup at Type{<:AbstractVector}: ", r === nothing ? "nothing" : length(r), " matches in ", round(t * 1e6; digits = 0), " us")
# an abstract member: every subtype is a member
abstract type Shape end
abstract type Poly end
struct Tri <: Poly end
fam(::Type{Shape}, ::Type{<:Poly}) = nothing
println("abstract member: Tri ", !isempty(look(Tuple{typeof(fam), Type{Shape}, Type{Tri}})),
        ", Poly ", !isempty(look(Tuple{typeof(fam), Type{Shape}, Type{Poly}})),
        ", Int ", !isempty(look(Tuple{typeof(fam), Type{Shape}, Type{Int}})))
