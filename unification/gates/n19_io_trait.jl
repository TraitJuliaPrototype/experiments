# Gate (W-129 (b); traits §9b; compiler §7.5, §4.8): `IO`, Base's trait of streams. `Core.IO` is a set from
# Core's build: a method typed `io::IO` is compiled once whatever the stream, Julia's own included; an
# operation on a stream typed `IO` infers its declared result, split over `IO`'s first candidates, the rest
# through the table, the result asserted; "a `String` is not an `IO`" is final since Base has loaded, so
# `isa` folds and a call carries no guard, while a type of Main stays guarded; `Dynamic{IO}` is an `IO`
# that plain code takes, an `IOContext`'s properties reaching `show` through it; a membership its type's
# owner declares later opens the pair's final cell and invalidates what relied on it; the system image
# keeps its sets' indices.
using Traits
include("util.jl")

guards(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal == 0x00]
finals(ci) = [e for e in ci.edges if e isa Core.MembershipCell && e.isfinal != 0x00]
latest(f, T...) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                c.def.specTypes === Tuple{typeof(f), T...}])
folded_false(c) = isdefined(c, :rettype_const) && (c.rettype_const === false ||
    (c.rettype_const isa Core.InterConditional && c.rettype_const.thentype === Union{}))

# (0) the set, its candidates and its operations, kept by the system image
@assert ccall(:jl_is_open_set, Cint, (Any,), IO) == 1
@assert ccall(:jl_get_default_attribute, Cint, (Any,), IO) == 3 "compiled once, Julia's own streams included"
@assert ccall(:jl_is_closed_after_load, Cint, (Any,), IO) == 1
cands = ccall(:jl_candidates_of, Any, (Any,), IO)::Vector{Any}
@assert length(cands) >= 4 && cands[1:4] == Any[IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint] "IO's first candidates: $cands"
for (f, n, rt) in ((write, 3, Integer), (unsafe_write, 4, Integer), (read, 3, UInt8), (eof, 2, Bool),
                   (Base.isopen, 2, Bool), (haskey, 3, Bool), (get, 4, Any), (flush, 2, Any))
    ms = ccall(:jl_declared_methods_of, Any, (Any,), typeof(f))::Vector{Any}
    @assert any(m -> m.declared_result === rt && m.nargs == n, ms) "$f's operation, declared $rt: $ms"
end
@assert !isempty(ccall(:jl_open_set_methods_of, Any, (Any,), IO)) "the image keeps its methods at IO"

# (1) compiled once, Julia's own streams included
kind(io::IO) = Core.keep(io) isa Core.Dynamic ? :dynamic : :compiled
@assert kind(IOBuffer()) === :dynamic && kind(devnull) === :dynamic && kind(IOContext(IOBuffer())) === :dynamic
emit(io::IO, x) = (print(io, x, ' '); nothing)
b = IOBuffer()
emit(b, 1); emit(IOContext(b, :compact => true), 2)
mktemp() do p, f
    emit(f, 3); close(f)
    @assert read(p, String) == "3 "
end
specs = [mi.specTypes for mi in Base.specializations(only(methods(emit)))]
@assert specs == Any[Tuple{typeof(emit), IO, Int}] "one instance at IO serves every stream: $specs"
@assert String(take!(b)) == "1 2 "
sm = which(show, (IOBuffer, Int))
@assert any(mi -> mi.specTypes === Tuple{typeof(show), IO, Int}, Base.specializations(sm)) "Base's show at IO"

# (2) an operation at a receiver typed `IO`: its declared result, split, asserted
wb(io::IO, x::UInt8) = write(io, x)
@assert Base.return_types(wb, (IO, UInt8)) == Any[Integer]
@assert wb(IOBuffer(), 0x41) == 1 && wb(IOContext(IOBuffer()), 0x41) == 1
let ir = first(only(code_typed(wb, (IO, UInt8))))
    inv = [st.args[1] for st in ir.code if Meta.isexpr(st, :invoke)]
    tys = [(inv[k] isa Core.CodeInstance ? inv[k].def : inv[k]).specTypes for k in eachindex(inv)]
    # the branches for the candidates past the first are direct calls; `IOBuffer`'s is inlined
    @assert all(T -> Tuple{typeof(write), T, UInt8} in tys, (IOStream, Base.TTY, Base.PipeEndpoint)) "the split's branches: $tys"
end
mutable struct CountIO <: IO; n::Int; end           # past the candidates: through the table
Base.write(c::CountIO, ::UInt8) = (c.n += 1; 1)
let c = CountIO(0)
    @assert wb(c, 0x41) == 1 && c.n == 1
end
struct BadIO <: IO end                               # a result that breaks the declaration
Base.write(::BadIO, ::UInt8) = "one"
@assert try wb(BadIO(), 0x41); false catch e; e isa TypeError end "the declared result asserted"

# (3) final negatives: `x isa IO` folds for a `String`; a call with a shadow at `IO` carries no guard
isio(x::String) = x isa IO
@assert isio("a") === false
@assert folded_false(latest(isio, String)) && length(finals(latest(isio, String))) == 1
pick(x) = :any
pick(io::IO) = :io
callp(s::String) = pick(s)
@assert callp("a") === :any
@assert isempty(guards(latest(callp, String))) && length(finals(latest(callp, String))) == 1
struct M end                                          # a type of Main is never settled
callm(m::M) = pick(m)
@assert callm(M()) === :any && length(guards(latest(callm, M))) == 1 && isempty(finals(latest(callm, M)))

# (4) `Dynamic{IO}` is an `IO`: plain code typed `io::IO` takes it; an `IOContext`'s property reaches `show`
inner = IOBuffer()
d = Core.Dynamic{IO}(IOContext(inner, :compact => true))
@assert d isa IO
@assert get(d, :compact, false) === true && haskey(d, :compact)
show(d, 1/3)
emit(d, 7)
@assert String(take!(inner)) == "0.333333" * "7 "

# (5) a membership its type's owner declares later opens the final cell and invalidates
module P
struct S end
end
ccall(:jl_module_set_loaded, Cvoid, (Any,), P)
callps(s::P.S) = pick(s)
isps(s::P.S) = s isa IO
@assert callps(P.S()) === :any && isps(P.S()) === false
ci = latest(callps, P.S)
cix = latest(isps, P.S)
@assert isempty(guards(ci)) && length(finals(ci)) == 1 "a final cell, no guard: $(ci.edges)"
cell = only(finals(ci))
w0 = curworld()
e = Traits.declare_membership(P.S, IO, P)
@assert cell.min_world == e.min_world "the final cell opened at the entry's world"
@assert ci.max_world == e.min_world - 1 && cix.max_world == e.min_world - 1 "its dependents invalidated"
@assert callps(P.S()) === :io && isps(P.S()) === true
@assert Base.invoke_in_world(w0, callps, P.S()) === :any "an older world keeps the old answer"

println("n19_io_trait: OK")
