# The declared-result report (E-333; traits §5.10, compiler §6.8): every method serving an operation
# with a declared result that covers every member, whose own result infers outside the declaration.
# traits §5.10 checks this at a membership. A set whose members join by a nominal supertype (Core's
# `IO`: `struct S <: IO`) has no such check, so a member whose method returns another type meets the
# declaration only when a call through the trait asserts it, as a `TypeError`.
#     julia-unified/julia --startup-file=no experiments/unification/audit/declared_results.jl [Pkg,Pkg,…] [n] [f=T,…] [core|all]
# Loads the packages (comma-separated, from the active project), then checks the operations of Core's
# sets (`IO`), whose members are not checked; `all` checks every operation, where a trait's members
# are checked at their own types and the report's inference at a method's own signature is wider. The
# third argument checks an operation against another declaration than its own (a proposed one:
# `write=Int,unsafe_write=Int`; `-` for none). An intersection no type of the world is in serves no
# member and is skipped (compiler §5.4). A report: it asserts nothing.
const CC = Base.Compiler

pkgs = length(ARGS) >= 1 && !isempty(ARGS[1]) ? split(ARGS[1], ',') : String[]
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 60
proposed = Dict{Symbol,Any}()
scope = length(ARGS) >= 4 ? ARGS[4] : "core"
if length(ARGS) >= 3 && ARGS[3] != "-"
    for kv in split(ARGS[3], ',')
        k, v = split(kv, '=')
        proposed[Symbol(k)] = Core.eval(Base, Meta.parse(v))
    end
end
for p in pkgs
    Core.eval(Main, :(using $(Symbol(p))))
end
world = Base.get_world_counter()
interp = CC.NativeInterpreter(world)

rootof(m::Module) = (p = parentmodule(m); (p === m || p === Main) ? m : rootof(p))

# the operations: a method whose declared result covers every member (bit 0 of `declared_covers`)
ops = Method[]
Base.visit(Core.methodtable) do m
    m isa Method || return
    (m.declared_covers & 0x01) != 0 && isdefined(m, :declared_result) || return
    if scope == "core"
        # an argument typed by one of Core's sets (not `Any`, which Core also defines)
        u = Base.unwrap_unionall(m.sig)
        coreset(@nospecialize p) = (r = Base.unwrap_unionall(p); r isa DataType && r.name.module === Core &&
                                    ccall(:jl_is_open_set, Cint, (Any,), r) == 1)
        any(coreset, u.parameters[2:end]) || return
    end
    push!(ops, m)
end

# a declared result in the operation's static parameters (`cell(c::Column{T}, i)::T`), instantiated at
# a serving method's signature; a parameter left free there widens to its bound
function declared_at(@nospecialize(R), @nospecialize(S₀), @nospecialize(spec))
    S₀ isa UnionAll || return R
    _, env = ccall(:jl_type_intersection_with_env, Any, (Any, Any), spec, S₀)::Core.SimpleVector
    vals = Any[v isa TypeVar ? v.ub : v for v in env]
    while length(vals) < length(Base.unwrap_unionall(S₀) === S₀ ? 0 : count_vars(S₀))
        push!(vals, Any)
    end
    Ri = try
        GC.@preserve vals ccall(:jl_instantiate_type_in_env, Any, (Any, Any, Ptr{Any}), R, S₀, vals)
    catch
        R isa TypeVar ? R.ub : Any
    end
    return Ri isa Type ? Ri : (Ri isa TypeVar ? Ri.ub : Any)
end
count_vars(@nospecialize(t)) = t isa UnionAll ? 1 + count_vars(t.body) : 0

struct Row
    op::Method
    R::Any
    method::Method
    rt::Any
end
rows = Row[]
nchecked = Dict{Method,Int}()
for m₀ in ops
    S₀ = m₀.sig
    R = get(proposed, m₀.name, m₀.declared_result)
    ft = Base.unwrap_unionall(S₀).parameters[1]
    n = 0
    Base.visit(Core.methodtable) do m
        m isa Method && m !== m₀ || return
        u = Base.unwrap_unionall(m.sig)
        (u isa DataType && length(u.parameters) >= 1 && u.parameters[1] == ft) || return
        ti = typeintersect(m.sig, S₀)
        ti === Union{} && return
        Base.has_unmet_intersection(ti, world) && return
        # the method serves where it is a match at the intersection: not shadowed there by a more specific one
        ms = Base._methods_by_ftype(ti, -1, world)
        ms isa Vector || return
        i = findfirst(x -> x.method === m, ms)
        i === nothing && return
        match = ms[i]::Core.MethodMatch
        rt = CC.typeinf_type(interp, match.method, match.spec_types, match.sparams)
        n += 1
        rt === nothing && return
        T = CC.widenconst(rt)
        Rm = declared_at(R, S₀, match.spec_types)
        T <: Rm || push!(rows, Row(m₀, Rm, m, T))
    end
    nchecked[m₀] = n
end

println("# the declared-result report: world $world, packages $(isempty(pkgs) ? "none" : join(pkgs, ", ")), operations: $scope")
println("operations with a covering declared result: $(length(ops))")
for m₀ in sort(ops; by = m -> string(m.name))
    R = get(proposed, m₀.name, m₀.declared_result)
    println("  $(m₀.name)$(Tuple{Base.unwrap_unionall(m₀.sig).parameters[2:end]...}) ::$R$(haskey(proposed, m₀.name) ? " (proposed; declared $(m₀.declared_result))" : ""): $(nchecked[m₀]) serving methods checked, ",
            count(r -> r.op === m₀, rows), " outside")
end
println()
println("serving methods whose result infers outside the declaration: $(length(rows))")
bypkg = Dict{Module,Int}()
for r in rows
    bypkg[rootof(r.method.module)] = get(bypkg, rootof(r.method.module), 0) + 1
end
println("by package: ", join(["$k $v" for (k, v) in sort(collect(bypkg); by = last, rev = true)], ", "))
byrt = Dict{Any,Int}()
for r in rows
    byrt[(r.op.name, r.rt)] = get(byrt, (r.op.name, r.rt), 0) + 1
end
println("by operation and inferred result: ", join(["$(k[1]) ::$(k[2]) $v" for (k, v) in sort(collect(byrt); by = last, rev = true)], ", "))
println()
for r in first(sort(rows; by = r -> (string(r.op.name), string(rootof(r.method.module)))), nshow)
    println("  $(r.op.name) ::$(r.R)  ← $(r.rt)   $(r.method.sig)  [$(r.method.file):$(r.method.line)]")
end
