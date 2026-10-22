# P15: a bounded function called in a loop by a typed plain caller, with a family member against
# members declared on their own (open issue 49; lowering §4.6, L-37). Nanoseconds and bytes per
# call, a hand loop after warm-up (best of 5). A quick regression check, not a measurement.
#   - FamS{Float64}: a member of the family `@implement Val15 FamS{T} where {T}`;
#   - S{Float32} and S{Float64}: the family `S{T} where {T}`, and S{Float64} declared on its own
#     after it (`@implement Val15 S{Float64}`), as a port declares its hot members;
#   - OwnS{Float64}: declared on its own, no family.
# Also the same work inside one bounded call (one entry, the loop in trait code) as the context.
# Reference: lowering L-37: `conformance` reaches `_conf_family` at every call (304 bytes per call
# against 0 for a declared type); traits §4.7 (planned: a member's typed calls cost what a declared
# type's do, W-40).
include("common.jl")
header("P15", "a bounded function called in a typed plain loop: family member against members declared on their own")

edef = caught(() -> toplevel(quote
    @trait_module module TW15
    using TraitWorld
    @trait Val15 begin
        getv(s::Val15, i::Int)::Float64
    end
    total(s::Val15, i::Int) = getv(s, i) + 1.0
    inner_loop(s::Val15, n::Int) = (acc = 0.0; for i in 1:n; acc += getv(s, i); end; acc)
    end
end))
println("trait module: ", errtext(edef))
edecl = caught(() -> toplevel(quote
    module M15
    using TraitWorld
    using ..TW15
    struct FamS{T}; x::Vector{T}; end
    TW15.getv(s::FamS, i::Int) = Float64(@inbounds s.x[1]) * i
    @implement TW15.Val15 FamS{T} where {T}
    struct OwnS{T}; x::Vector{T}; end
    TW15.getv(s::OwnS, i::Int) = Float64(@inbounds s.x[1]) * i
    @implement TW15.Val15 OwnS{Float64}
    struct S{T}; x::Vector{T}; end
    TW15.getv(s::S, i::Int) = Float64(@inbounds s.x[1]) * i
    @implement TW15.Val15 S{T} where {T}
    end
end))
println("declarations: ", errtext(edecl))
eone = caught(() -> toplevel(:(@eval M15 @implement TW15.Val15 S{Float64})))
println("S{Float64} declared on its own after the family: ", errtext(eone; lines = 3))

function plain_loop(s, n::Int)
    acc = 0.0
    for i in 1:n
        acc += TW15.total(s, i)
    end
    return acc
end
const N = 1_000_000
cases = [
    ("FamS{Float64}, family member", M15.FamS([1.0])),
    ("S{Float32}, family member (the family also has S{Float64} declared)", M15.S(Float32[1])),
    ("S{Float64}, declared on its own after the family", M15.S([1.0])),
    ("OwnS{Float64}, declared on its own", M15.OwnS([1.0])),
]
res = Dict{String,Any}()
println("\nthe bounded function `total(s::Val15, i)` called N = $N times from a typed plain loop:")
for (lbl, s) in cases
    r = try percall(let s = s; n -> plain_loop(s, n); end, N) catch e; (ns = NaN, bytes = NaN, err = inner_err(e)) end
    res[lbl] = r
    @printf("  %-70s %8.2f ns/call %8.1f bytes/call%s\n", lbl, r.ns, r.bytes, haskey(r, :err) ? "  " * errtext(r.err; lines = 2) : "")
end
println("\ncontext: the same work in one bounded call (`inner_loop(s::Val15, n)`, the loop in trait code), per iteration:")
res_in = Dict{String,Any}()
for (lbl, s) in cases
    r = try percall(let s = s; n -> TW15.inner_loop(s, n); end, N) catch e; (ns = NaN, bytes = NaN, err = inner_err(e)) end
    res_in[lbl] = r
    @printf("  %-70s %8.2f ns/iter %8.1f bytes/iter%s\n", lbl, r.ns, r.bytes, haskey(r, :err) ? "  " * errtext(r.err; lines = 2) : "")
end
println("results agree: ", [plain_loop(s, 10) for (_, s) in cases])
println()

fam = res["FamS{Float64}, family member"]; own = res["OwnS{Float64}, declared on its own"]
check("the declarations are accepted", edef === nothing && edecl === nothing, "$(errtext(edef)); $(errtext(edecl))")
check("OwnS{Float64}, declared on its own: no allocation per call", own.bytes < 0.5, @sprintf("%.6f bytes/call", own.bytes))
check("FamS{Float64}, family member: allocates per call (L-37)", fam.bytes > 0, @sprintf("%.1f bytes/call, %.2f ns against %.2f ns", fam.bytes, fam.ns, own.ns))
check("S{Float64} declared on its own after the family is accepted (lowering §4.6: a more specific conformance method)", eone === nothing, errtext(eone; lines = 2))
if eone === nothing
    d = res["S{Float64}, declared on its own after the family"]
    check("S{Float64}, declared on its own after the family: no allocation per call", d.bytes < 0.5, @sprintf("%.6f bytes/call", d.bytes))
end
finish("P15";
    predicted = "the family member: 304 bytes per call; the declared member: none",
    reference = "lowering L-37: a family member's typed call goes through the registry, 304 bytes per call against 0 for a declared type (planned fix W-40)",
    prediction = @sprintf("family member %.1f bytes/call (predicted 304), declared %.1f (predicted 0)", fam.bytes, own.bytes))
