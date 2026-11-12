# Gate (W-129 (c), E-337; traits §3.4, §9b; compiler §7.1, §7.2, §7.5): `IO`'s contract. `IO` is Julia's
# closed abstract type: a method typed `io::IO` is compiled per stream type, as in Julia, and `isa` folds
# with no cell or guard. Its contract, written by Base and kept by the system image, gives an operation on
# a value typed `IO` (an argument declared `@nospecialize`, a field) a split over `IO`'s first
# candidates and through the table past them. A closed type promises no result (open issue 171): each
# operation's result is `Any`, and a call through `IO` returns what the stream's own method returns, as
# a dynamic call and the interpreter do.
# The erased stream is `IOContext{IO}`: one type whatever the stream, its properties reaching `show`, its
# operations on the stream it holds split.
using Traits
include("util.jl")

latest(f, T...) = only([c for c in all_cis(f) if c.owner === nothing && c.max_world == typemax(UInt) &&
                                                c.def.specTypes === Tuple{typeof(f), T...}])
cells(ci) = absences(ci)
folded_false(c) = isdefined(c, :rettype_const) && (c.rettype_const === false ||
    (c.rettype_const isa Core.InterConditional && c.rettype_const.thentype === Union{}))

# (0) a closed abstract type with a contract, its candidates and operations kept by the system image
@assert ccall(:jl_is_open_set, Cint, (Any,), IO) == 0 "IO is no set"
@assert ccall(:jl_has_contract, Cint, (Any,), IO) == 1 "IO has a contract"
@assert ccall(:jl_has_contract, Cint, (Any,), AbstractString) == 0
cands = ccall(:jl_candidates_of, Any, (Any,), IO)::Vector{Any}
@assert cands == Any[IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint] "IO's candidates: $cands"
ops = ccall(:jl_contract_operations, Any, (Any,), IO)::Core.SimpleVector
for (f, n) in ((write, 3), (unsafe_write, 4), (read, 3), (haskey, 3), (get, 4), (flush, 2), (lock, 2),
               (unlock, 2), (unsafe_read, 4))
    @assert any(m -> m.name === nameof(f) && m.declared_result === Any && m.nargs == n, ops) "$f's operation, its result Any: $ops"
end
@assert !any(m -> m.name in (:eof, :isopen, :close), ops) "eof, isopen and close are not operations"
@assert !hasmethod(eof, Tuple{IO}) && !hasmethod(close, Tuple{IO}) "no defaults at ::IO"

# (1) compiled per stream type, as in Julia
emit(io::IO, x) = (print(io, x, ' '); nothing)
b = IOBuffer()
emit(b, 1); emit(IOContext(b, :compact => true), 2)
mktemp() do p, f
    emit(f, 3); close(f)
    @assert read(p, String) == "3 "
end
specs = Set(mi.specTypes for mi in Base.specializations(only(methods(emit))))
@assert Tuple{typeof(emit), IOBuffer, Int} in specs && Tuple{typeof(emit), IOStream, Int} in specs &&
        !(Tuple{typeof(emit), IO, Int} in specs) "an instance per stream type: $specs"
@assert String(take!(b)) == "1 2 "
@assert typeof(IOContext(IOBuffer())) === IOContext{IOBuffer} "IOContext keeps the stream's type"

# (2) an operation at a value typed `IO`: split, its result the stream's own
wb(@nospecialize(io::IO), x::UInt8) = write(io, x)
@assert Base.return_types(wb, (IO, UInt8)) == Any[Any]
@assert wb(IOBuffer(), 0x41) == 1 && wb(IOContext(IOBuffer()), 0x41) == 1
let ir = first(only(code_typed(wb, (IO, UInt8))))
    # a branch whose body calls further (`write(::IOBuffer, ::UInt8)` may grow the buffer) calls its target
    # through a `:caller_world` pointer (compiler §7.2), and the caller holds no edge to it
    cfs = [st.args[2].value for st in ir.code if Meta.isexpr(st, :cfunction)]
    tgts = [typeof(t).parameters[2] for t in cfs if typeof(t) <: Base._SplitTarget]
    @assert all(T -> T in tgts, (IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint)) "the split's pointers: $tgts"
    ci = latest(wb, IO, UInt8)
    spec(e) = e isa Core.CodeInstance ? e.def.specTypes : e isa Core.MethodInstance ? e.specTypes : nothing
    edged = [spec(e) for e in ci.edges if spec(e) isa DataType && length(spec(e).parameters) >= 2]
    @assert !any(t -> t.parameters[2] in (IOBuffer, IOStream, Base.TTY, Base.PipeEndpoint), edged) "no edge to a candidate's instance: $(ci.edges)"
end
mutable struct CountIO <: IO; n::Int; end           # past the candidates: through the table
Base.write(c::CountIO, ::UInt8) = (c.n += 1; 1)
let c = CountIO(0)
    @assert wb(c, 0x41) == 1 && c.n == 1
end
struct UIntIO <: IO end                              # another integer type: the stream's own result
Base.write(::UIntIO, ::UInt8) = UInt(1)
Base.unsafe_write(::UIntIO, ::Ptr{UInt8}, n::UInt) = n
@assert wb(UIntIO(), 0x41) === UInt(1) && wb(IOContext{IO}(UIntIO()), 0x41) === UInt(1)
@assert write(Any[UIntIO()][1], 0x41) === UInt(1) && write(IO[UIntIO()][1], 0x41) === UInt(1) "through Any and through IO alike"
struct BadIO <: IO end                               # any result: the stream's own
Base.write(::BadIO, ::UInt8) = "one"
@assert wb(BadIO(), 0x41) == "one" && write(IO[BadIO()][1], 0x41) == "one"
# the eraser built in the caller's frame: constant propagation sees the stream's type, inference at the
# eraser does not; the code returns what its type says (the documentation's H4, the plan review's H1)
struct V7 <: IO end
Base.write(::V7, x::UInt8) = UInt(7)
wbs(io::IO, x::UInt8) = write(io, x)
let f = () -> wbs(IOContext{IO}(V7()), 0x01), g = () -> wb(V7(), 0x01)
    @assert f() === UInt(7) && g() === UInt(7)
    @assert all(T -> UInt <: T, Base.return_types(f, ())) "the closure's type admits its value: $(Base.return_types(f, ()))"
end
# the interpreter gives the same answers
let out = read(`$(Base.julia_cmd()) --startup-file=no --compile=min -e '
        struct U <: IO end; Base.write(::U, ::UInt8) = UInt(1); w(@nospecialize(io::IO)) = write(io, 0x41)
        print(repr(w(U())), " ", repr(write(IO[U()][1], 0x41)))'`, String)
    @assert out == "0x0000000000000001 0x0000000000000001" "--compile=min: $out"
end
struct Holder; io::IO; end                           # a field typed `IO`
wh(h::Holder) = write(h.io, 0x42)
@assert Base.return_types(wh, (Holder,)) == Any[Any] && wh(Holder(IOBuffer())) == 1

# a caller in an old world of Base's build (a generated function's generator runs in the world it was
# defined in): the pointer's target and the table's miss serve it
let mw = only(methods(Base._split_table_miss!)).primary_world - 1, bs = Base.BufferStream()
    @assert Base.invoke_in_world(mw, write, IOContext{IO}(bs), "abc") == 3 "the table's miss in an old world"
    mktemp() do p, f
        @assert Base.invoke_in_world(mw, write, IOContext{IO}(f), "xyz") == 3 "a pointer branch in an old world"
        close(f)
    end
    close(bs)
    @assert read(bs, String) == "abc"
end

# (3) `IO` is closed: `isa` folds and a call carries no guard, with no cell, whatever the type's module
isio(x::String) = x isa IO
@assert isio("a") === false && folded_false(latest(isio, String)) && isempty(cells(latest(isio, String)))
pick(x) = :any
pick(io::IO) = :io
struct M end
callm(m::M) = pick(m)
@assert callm(M()) === :any && isempty(cells(latest(callm, M)))
@assert try Traits.declare_membership(M, IO, Main); false catch; true end "no membership in a closed type"

# (4) the erased stream `IOContext{IO}`: one type, the stream's and the given properties, `show` through it
inner = IOBuffer()
d = IOContext{IO}(inner, :compact => true)
@assert typeof(d) === IOContext{IO} && d.io === inner
@assert get(d, :compact, false) === true && haskey(d, :compact)
show(d, 1/3)
emit(d, 7)
@assert String(take!(inner)) == "0.333333" * "7 "
d2 = IOContext{IO}(IOContext(inner, :limit => true), :compact => true)
@assert typeof(d2) === IOContext{IO} && d2.io === inner && get(d2, :limit, false) && get(d2, :compact, false) "an IOContext unwrapped, its properties kept"
@assert typeof(IOContext{IO}(IOContext(inner, :limit => true))) === IOContext{IO}
# the eraser forwards the stream's whole interface, not the contract's operations alone
struct DS <: IO end
Base.displaysize(::DS) = (7, 9)
@assert displaysize(IOContext{IO}(DS())) == (7, 9) "a terminal's size through the eraser"
let e = IOContext{IO}(IOBuffer("abc"))
    read(e, UInt8); mark(e); @assert ismarked(e)
    read(e, UInt8); reset(e)
    @assert read(e, UInt8) == UInt8('b') "mark and reset through the eraser"
end
# a display entry that erases: one instance serves every stream
shw(@nospecialize(io::IO), x) = (show(IOContext{IO}(io), x); nothing)
# reached by a dynamic call, as the REPL's display reaches `show` (a caller that knows the stream may
# still infer the entry at it: `@nospecialize` decides the compiled code, not inference)
mktemp() do p, f
    for io in Any[IOBuffer(), IOContext(IOBuffer(), :compact => true), f]
        shw(io, 2.5)
    end
    close(f)
    @assert read(p, String) == "2.5"
end
let s = [mi.specTypes for mi in Base.specializations(only(methods(shw)))]; @assert s == Any[Tuple{typeof(shw), IO, Float64}] "one instance: $s"; end
@assert Tuple{typeof(show), IOContext{IO}, Float64} in Set(mi.specTypes for mi in Base.specializations(which(show, (IOContext{IO}, Float64)))) "show at the erased stream"

println("n19_io_trait: OK")
