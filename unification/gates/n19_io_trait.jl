# Gate (W-129 (b); traits §9b; compiler §7.5, §4.8): `IO`, Base's trait of streams. `Core.IO` is a set from
# Core's build: a method typed `io::IO` is compiled once whatever the stream, Julia's own included; an
# operation on a stream typed `IO` infers its declared result, split over `IO`'s first candidates, the rest
# through the table, the result converted to the declared result (Base's streams already return it); "a `String` is not an `IO`" is final since Base has loaded, so
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
for (f, n, rt) in ((write, 3, Int), (unsafe_write, 4, Int), (read, 3, UInt8), (eof, 2, Bool),
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
@assert Base.return_types(wb, (IO, UInt8)) == Any[Int]
@assert wb(IOBuffer(), 0x41) == 1 && wb(IOContext(IOBuffer()), 0x41) == 1
let ir = first(only(code_typed(wb, (IO, UInt8))))
    # a branch whose body calls further (`write(::IOBuffer, ::UInt8)` may grow the buffer) calls its target
    # through a `:caller_world` pointer (compiler §7.2, open issue 167), and the caller holds no edge to it
    cfs = [st.args[2].value for st in ir.code if Meta.isexpr(st, :cfunction)]
    tgts = [typeof(t).parameters[2] for t in cfs if typeof(t) <: Base._SplitTarget]
    @assert all(T -> T in tgts, (IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint)) "the split's pointers: $tgts"
    invoked(st) = (c = st.args[1]; mi = c isa Core.CodeInstance ? c.def : c; mi isa Core.MethodInstance ? mi.def : nothing)
    @assert !any(st -> Meta.isexpr(st, :invoke) && (m = invoked(st)) isa Method && m.name === :write, ir.code) "no direct call of a candidate's write: $ir"
    wb(IOBuffer(), 0x41)
    ci = latest(wb, IO, UInt8)
    spec(e) = e isa Core.CodeInstance ? e.def.specTypes : e isa Core.MethodInstance ? e.specTypes : nothing
    edged = [spec(e) for e in ci.edges if spec(e) isa DataType && length(spec(e).parameters) >= 2]
    @assert !any(t -> t.parameters[2] in (IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint), edged) "no edge to a candidate's instance: $(ci.edges)"
end
# a leaf branch, calling only builtins (`isopen(::IOBuffer)` reads fields), is inlined
op(io::IO) = Base.isopen(io)
let ir = first(only(code_typed(op, (IO,))))
    tgts = [typeof(st.args[2].value).parameters[2] for st in ir.code if Meta.isexpr(st, :cfunction)]
    @assert !(IOBuffer in tgts) && any(st -> Meta.isexpr(st, :call) && (st.args[1] == GlobalRef(Core, :isa) || st.args[1] === isa) && st.args[3] === IOBuffer, ir.code) "isopen(::IOBuffer) inlined: $ir"
    @assert op(IOBuffer()) === true
end
mutable struct CountIO <: IO; n::Int; end           # past the candidates: through the table
Base.write(c::CountIO, ::UInt8) = (c.n += 1; 1)
let c = CountIO(0)
    @assert wb(c, 0x41) == 1 && c.n == 1
end
struct UIntIO <: IO end                              # another integer type: converted, as `f(…)::Int` would
Base.write(::UIntIO, ::UInt8) = UInt(1)
Base.unsafe_write(::UIntIO, ::Ptr{UInt8}, n::UInt) = n
ws(io::IO, s::String) = write(io, s)
@assert wb(UIntIO(), 0x41) === 1 && ws(UIntIO(), "abc") === 3 && wb(Core.Dynamic{IO}(UIntIO()), 0x41) === 1
struct BadIO <: IO end                               # a result that does not convert raises
Base.write(::BadIO, ::UInt8) = "one"
@assert try wb(BadIO(), 0x41); false catch e; e isa MethodError || e isa TypeError end "the declared result enforced"
# Base's streams return their counts as `Int`, so their branches convert nothing (the declared-result
# report, audit/declared_results.jl, over every package)
for S in (Tuple{typeof(write), IO, UInt8}, Tuple{typeof(unsafe_write), IO, Ptr{UInt8}, UInt})
    for m in methods(S.parameters[1].instance)
        (m.module === Base || parentmodule(m.module) === Base) && (m.declared_covers & 0x01) == 0 || continue
        ti = typeintersect(m.sig, S)
        ti === Union{} && continue
        ms = Base._methods_by_ftype(ti, -1, Base.get_world_counter())
        i = findfirst(x -> x.method === m, ms)
        i === nothing && continue
        mt = ms[i]
        rt = Base.Compiler.typeinf_type(Base.Compiler.NativeInterpreter(), mt.method, mt.spec_types, mt.sparams)
        @assert rt === nothing || Base.Compiler.widenconst(rt) <: Int "Base's $m returns $rt"
    end
end

# a caller in an old world of Base's build (a generated function's generator runs in the world it was
# defined in): the pointer's target and the table's miss serve it
let mw = only(methods(Base._split_table_miss!)).primary_world - 1, b = IOBuffer()
    @assert Base.invoke_in_world(mw, write, IOContext(b), "abc") == 3 "the table's miss in an old world"
    mktemp() do p, f
        @assert Base.invoke_in_world(mw, write, f, "xyz") == 3 "a pointer branch in an old world"
        close(f)
    end
    @assert String(take!(b)) == "abc"
end

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
