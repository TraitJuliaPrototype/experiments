# Gate (compiler C-81, §7.1, §7.2; traits §3.4): a closed abstract type's contract names its operations
# and its candidates, written once on the type's TypeName, so a package image keeps both. A candidate is
# a concrete subtype, named once; registering one later is refused; a contract is declared in the image
# that defines the type. In a fresh depot: after a package's image is loaded, its type's candidates are
# there, a call at a value typed by the type splits over them, and a type past them goes through the table.
using Traits
include("util.jl")
declare(T, ops, cands) = ccall(:jl_declare_contract, Cvoid, (Any, Any, Any), T, Core.svec(ops...), Core.svec(cands...))
candidates(T) = ccall(:jl_candidates_of, Any, (Any,), T)::Vector{Any}
raises(f) = try f(); false catch; true end

# (0) in a session: the rules of the declaration
abstract type AQ end
struct Q1 <: AQ end
struct Q2 <: AQ end
struct Q3 <: AQ end
opq(x::AQ) = error("no method")
opq(::Q1) = 1; opq(::Q2) = 2; opq(::Q3) = 3
mq = which(opq, (AQ,))
ccall(:jl_method_set_declared_result, Cvoid, (Any, Any, Cint), mq, Any, 1)
abstract type AR end
@assert raises(() -> declare(AR, [mq], [Q1])) "a candidate is a subtype"
@assert raises(() -> declare(AR, [mq], [AR])) "a candidate is concrete"
declare(AQ, [mq], [Q1, Q2])
@assert candidates(AQ) == Any[Q1, Q2]
@assert raises(() -> declare(AQ, [mq], [Q1])) "written once"
@assert raises(() -> ccall(:jl_register_candidate, Cvoid, (Any, Any), AQ, Q3)) "no candidate registered later"
@assert candidates(AQ) == Any[Q1, Q2]
@assert raises(() -> ccall(:jl_register_candidate, Cvoid, (Any, Any), IO, Base.BufferStream)) "IO's candidates are its contract's"
@assert raises(() -> declare(Base.AbstractDisplay, [], [])) "declared in the image that defines the type"
callq(v::Vector{AQ}) = opq(v[1])
@assert callq(AQ[Q1()]) == 1 && callq(AQ[Q3()]) == 3

# (1) a package's contract on its own type, after its image is loaded
const ROOT = mktempdir()
const PKGS = joinpath(ROOT, "pkgs")
const DEPOT = joinpath(ROOT, "depot")
mkpath(DEPOT); mkpath(joinpath(PKGS, "PkgC", "src"))
write(joinpath(PKGS, "PkgC", "src", "PkgC.jl"), """
module PkgC
abstract type A end
struct A1 <: A; v::Vector{Int}; end
struct A2 <: A; v::Vector{Int}; end
struct A3 <: A; v::Vector{Int}; end
opa(x::A) = error("no method")
opa(a::A1) = (push!(a.v, 1); length(a.v))       # bodies that call further: the split's pointers
opa(a::A2) = (push!(a.v, 2); length(a.v))
opa(a::A3) = (push!(a.v, 3); length(a.v))
let m = which(opa, (A,))
    ccall(:jl_method_set_declared_result, Cvoid, (Any, Any, Cint), m, Any, 1)
    ccall(:jl_declare_contract, Cvoid, (Any, Any, Any), A, Core.svec(m), Core.svec(A1, A2))
end
callv(v::Vector{A}) = opa(v[1])
precompile(callv, (Vector{A},))
end
""")
const UNIF = dirname(@__DIR__)
function child(code)
    env = copy(ENV)
    env["JULIA_DEPOT_PATH"] = DEPOT * ":" * join(DEPOT_PATH[2:end], ":")
    env["JULIA_LOAD_PATH"] = join([PKGS, UNIF, "@stdlib"], ":")
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(setenv(`$(Base.julia_cmd()) --startup-file=no -e $code`, env); stdout = out, stderr = err))
    return ok, String(take!(out)), String(take!(err))
end
let (ok, out, err) = child("using PkgC")
    @assert ok "PkgC precompiles: $err"
end
let (ok, out, err) = child("""
        using PkgC
        print(repr(ccall(:jl_candidates_of, Any, (Any,), PkgC.A)), "|")
        print(ccall(:jl_has_contract, Cint, (Any,), PkgC.A), "|")
        print(PkgC.callv(PkgC.A[PkgC.A1(Int[])]), PkgC.callv(PkgC.A[PkgC.A3(Int[])]), "|")
        ir = first(only(code_typed(PkgC.callv, (Vector{PkgC.A},))))
        cfs = [st.args[2].value for st in ir.code if Meta.isexpr(st, :cfunction)]
        tgts = [typeof(t).parameters[2] for t in cfs if typeof(t) <: Base._SplitTarget]
        isas = [st.args[3] for st in ir.code if Meta.isexpr(st, :call) && length(st.args) == 3 && st.args[1] == GlobalRef(Core, :isa)]
        print(PkgC.A1 in tgts || PkgC.A1 in isas, PkgC.A2 in tgts || PkgC.A2 in isas, "|")
        print(try ccall(:jl_register_candidate, Cvoid, (Any, Any), PkgC.A, PkgC.A3); "registered" catch; "refused" end)
        """)
    @assert ok "the child: $err"
    parts = split(out, "|")
    @assert parts[1] == "Any[PkgC.A1, PkgC.A2]" "the candidates after the image is loaded: $(parts[1])"
    @assert parts[2] == "1" "the contract after the image is loaded"
    @assert parts[3] == "11" "the calls: $(parts[3])"
    @assert parts[4] == "truetrue" "the split names both candidates: $(parts[4])"
    @assert parts[5] == "refused" "no candidate registered after load"
end
println("n23_contract_image: OK")
