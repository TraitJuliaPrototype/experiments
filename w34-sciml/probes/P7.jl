# P7: a default whose body names the trait's parameter (`state(m::M{T}, u0)::Vector{T} = Vector{T}(u0)`).
# Reference: traits §3.2 (the trait's parameters are in scope in a default's body) with deviation
# T-2 (`UndefVarError: T` when the default runs).
include("common.jl")
header("P7", "a default whose body names the trait's parameter")

edef = caught(() -> toplevel(quote
    @trait_module module TraitPkg
    using TraitWorld
    @trait Model{T} begin
        T = eltype(Self)
        mlen(m::Model)::Int
        state(m::Model{T}, u0::Vector{Float64})::Vector{T} = Vector{T}(u0)      # names T in the body
        zero_state(m::Model{T})::Vector{T} = zeros(T, mlen(m))                  # names T, calls an operation
    end
    start(m::Model{T}) where {T} = state(m, [1.0, 2.0])
    zs(m::Model) = zero_state(m)
    end
end))
println("trait module: ", errtext(edef))
edecl = caught(() -> toplevel(quote
    module Models
    using TraitWorld
    using ..TraitPkg
    struct M32; n::Int; end
    Base.eltype(::Type{M32}) = Float32
    TraitPkg.mlen(m::M32) = m.n
    @implement TraitPkg.Model M32
    end
end))
println("declaration: ", errtext(edecl))
callres(f) = try (true, Base.invokelatest(f)) catch e; (false, inner_err(e)) end
show_r(r) = r[1] ? "returned $(repr(r[2]))" : errtext(r[2]; lines = 3)
typed_start(m::Models.M32) = TraitPkg.start(m)
r1 = callres(() -> typed_start(Models.M32(2)))
r2 = callres(() -> TraitPkg.zs(Models.M32(3)))
println("state(M32) via start, typed: ", show_r(r1))
println("zero_state(M32) at the top level: ", show_r(r2))
println()
t2(r) = !r[1] && r[2] isa UndefVarError && r[2].var === :T
check("the trait and the implementation are accepted", edef === nothing && edecl === nothing, "$(errtext(edef)); $(errtext(edecl))")
check("state(m, u0): UndefVarError T when the default runs (T-2)", t2(r1), show_r(r1))
check("zero_state(m): UndefVarError T when the default runs (T-2)", t2(r2), show_r(r2))
finish("P7";
    predicted = "`UndefVarError` (T-2)",
    reference = "traits §3.2: the parameters are in scope in a default's body (Planned), Deviation T-2: `UndefVarError: T` when the default runs",
    prediction = "see the checks: yes where every check is ok")
