# Heterogeneous collections at scale (the review's example 8): a `Vector{Dynamic{Shape}}` holding
# values of 2, 4, 16 and 64 conforming types, from a package image (HShapes) and from the prompt,
# against the plain twin (an abstract type with 64 subtypes). Code and correctness here; no timing
# (the current numbers for `Dynamic` values: writeup/design/evidence.md).
#
#     julia --project=../env collections.jl
#
# Expected (design.md §3.4 mechanism 3, §4.5):
#   - `total` computes plain Julia's value for every n and every mix of image and prompt types;
#   - one compiled `total`, whatever n (no specialization per element type);
#   - conformances declared at the prompt invalidate none of HShapes' compiled code;
#   - a value of a type declared at the prompt works in the `total` compiled before it existed.
include(joinpath(@__DIR__, "..", "common.jl"))
using HShapes
using TraitWorld
const SC = HShapes.ShapeCore
const PS = HShapes.PlainShapes
println("julia ", VERSION, "  facts mode (all): ", facts_mode())
nspec() = sum(m -> count(mi -> mi isa Core.MethodInstance, Base.specializations(m)), methods(SC.total))
tri(n) = n * (n + 1) / 2
spec = Int[]
for n in (2, 4, 16, 64)
    t = total(HShapes.traitvals(n)); p = PS.ptotal(HShapes.plainvals(n))
    check("n = $n from the image: total = plain = $(tri(n))", t == p == tri(n), "trait $t, plain $p")
    push!(spec, nspec())
end
check("one set of compiled `total` code for every n", allequal(spec), "specializations of total after each n: $spec")

# conformances from the prompt
cis = valid_cis(HShapes)
pcis = filter(ci -> _within(_cimodule(ci), PS), cis)
for i in 1:64
    toplevel(quote
        struct $(Symbol(:Q, i)); a::Float64; end
        @implement HShapes.Shape{$(Symbol(:Q, i))} begin area(s) = $(100.0 + i) * s.a end
        struct $(Symbol(:PQ, i)) <: HShapes.PlainShapes.PShape; a::Float64; end
        HShapes.PlainShapes.parea(s::$(Symbol(:PQ, i))) = $(100.0 + i) * s.a
    end)
end
check("64 conformances at the prompt invalidate none of HShapes' trait code", nlost(setdiff(cis, pcis)) == 0,
      "$(nlost(setdiff(cis, pcis))) of $(length(cis) - length(pcis)) lost")
println("     plain twin: $(nlost(pcis)) of $(length(pcis)) CodeInstances lost to 64 new subtypes ",
        "(0 expected on 1.13: with 64 methods the call at PShape records no edge; S2 shows the 2-method case)")
for n in (2, 4, 16, 64)
    vq = Base.invokelatest(() -> Dynamic{HShapes.Shape}[HShapes.mk(getfield(Main, Symbol(:Q, i))(1.0)) for i in 1:n])
    pq = Base.invokelatest(() -> HShapes.PlainShapes.PShape[getfield(Main, Symbol(:PQ, i))(1.0) for i in 1:n])
    t = Base.invokelatest(total, vq); p = Base.invokelatest(PS.ptotal, pq); e = 100.0n + tri(n)
    check("n = $n from the prompt: total = plain = $e", t == p == e, "trait $t, plain $p")
end
mix = Base.invokelatest(() -> vcat(HShapes.traitvals(64), Dynamic{HShapes.Shape}[HShapes.mk(getfield(Main, Symbol(:Q, i))(1.0)) for i in 1:64]))
pmix = Base.invokelatest(() -> vcat(HShapes.plainvals(64), HShapes.PlainShapes.PShape[getfield(Main, Symbol(:PQ, i))(1.0) for i in 1:64]))
t = Base.invokelatest(total, mix); p = Base.invokelatest(PS.ptotal, pmix)
check("128 types mixed, image and prompt: total = plain", t == p == 100.0 * 64 + 2tri(64), "trait $t, plain $p")
check("still one set of compiled `total` code", nspec() == spec[end], "$(nspec()) against $(spec[end])")
# The call-site split of part (D), which is built (writeup/state.md): `area(d)` in `total` becomes
# `isa` branches over the first four registered implementations, then a dynamic fallback, with no
# edge to the candidate list (writeup/reference/compiler.md §4.2). Not checked here yet.
pending("the call-site split: `area(d)` in `total` split over declared conformances",
        "a check that reads the split from `total`'s compiled code (part (D) is built)")
# To measure (not run here):
#   - time per element of `total` at 10^3 and 10^6 elements for n = 2, 4, 16, 64, 128 (image,
#     prompt, mixed) against `ptotal` (plain: fast for n <= max_methods, dynamic dispatch above);
#   - CodeInstances and image bytes per added conformance in HShapes (the "explosion" volume);
#   - the first call of `total` after 64 prompt conformances (no recompile expected).
summary()
