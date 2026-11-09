# The erasure report (open issue 166): in the methods of a module whose argument is typed by a set and
# compiled once (Base's methods typed `io::IO`), the calls left to dispatch when they run on a value of
# the set: not one of the set's operations (those are split), with more matching methods than inference
# unions. Their results lose their types downstream, and the instances they reach are in an image only
# if its build ran them. Grouped by function, most sites first: the common calls are the candidates for
# an operation with a declared result (166 (c)), or for an image to hold their targets (166 (a)).
#     julia-unified/julia --startup-file=no experiments/unification/audit/erased_calls.jl [Module] [Set] [n]
# Defaults: Base, IO, the first 40 functions. A report: it asserts nothing.
const CC = Base.Compiler

root = length(ARGS) >= 1 ? getfield(Main, Symbol(ARGS[1])) : Base
X = length(ARGS) >= 2 ? getfield(Core, Symbol(ARGS[2])) : IO
nshow = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 40
@assert ccall(:jl_is_open_set, Cint, (Any,), X) == 1 "$X is not a set"

# the module's package: the module below `Main` (Base's parent is `Main`), or a toplevel module
rootof(m::Module) = (p = parentmodule(m); (p === m || p === Main) ? m : rootof(p))
# an argument typed by the set itself: compiled once where its attribute is `Dynamic`
settyped(@nospecialize(t)) = (u = Base.unwrap_unionall(t); u isa DataType && u.name === Base.unwrap_unionall(X).name)
# a value known only as a stream: of the set, and not of one concrete type
erased(@nospecialize(t)) = (T = CC.widenconst(t); T isa Type && T !== Union{} && !isconcretetype(T) && T <: X)

# The wrappers over the set: a type of the module whose parameter, bounded by the set, types a field. Built from
# a value of the set in code compiled once (`W(io)` takes `typeof(io)`), it is abstract, so every call on it
# dispatches when it runs; held as the set (`W{X}`), it is concrete.
wrappers = Tuple{Any,Symbol,Symbol}[]
function scan_wrappers(m::Module, seen = Set{Module}())
    m in seen && return
    push!(seen, m)
    for n in names(m; all = true)
        isdefined(m, n) || continue
        v = getfield(m, n)
        if v isa Module
            parentmodule(v) === m && v !== m && scan_wrappers(v, seen)
        elseif v isa Type
            u = Base.unwrap_unionall(v)
            (u isa DataType && u.name.module === m && u.name.name === n && isstructtype(u)) || continue
            for (fname, ft) in zip(fieldnames(u), u.types)
                ft isa TypeVar && ft.ub !== Union{} && ft.ub <: X && push!(wrappers, (v, ft.name, fname))
            end
        end
    end
end
scan_wrappers(root)

methods_at = Method[]
Base.visit(Core.methodtable) do m
    m isa Method || return
    rootof(m.module) === root || return
    sig = Base.unwrap_unionall(m.sig)
    sig isa DataType || return
    any(settyped, sig.parameters[2:end]) && push!(methods_at, m)
end

struct Site
    method::Method
    rt::Any
    recv::Any   # the first argument known only as a stream: its type
end
calls = Dict{Any,Vector{Site}}()
failed = 0
nsplit = 0
nattr = 0
interp = CC.NativeInterpreter()
for m in methods_at
    env = ccall(:jl_type_intersection_with_env, Any, (Any, Any), m.sig, m.sig)::Core.SimpleVector
    ir = try
        CC.typeinf_ircode(interp, m, m.sig, env[2], nothing)[1]
    catch
        nothing
    end
    if ir === nothing
        global failed += 1
        continue
    end
    for i in 1:length(ir.stmts)
        st = ir.stmts[i][:stmt]
        Meta.isexpr(st, :call) || continue
        f = CC.argextype(st.args[1], ir)
        fv = f isa Core.Const ? f.val : CC.singleton_type(CC.widenconst(f))
        # `Core.attributed_call(bits, g, args...)`: a dynamic call of `g` that passes its arguments'
        # attributes on (compiler §6.3); counted as a call of `g`
        args = st.args[2:end]
        if fv === Core.attributed_call && length(st.args) >= 3
            f = CC.argextype(st.args[3], ir)
            fv = f isa Core.Const ? f.val : CC.singleton_type(CC.widenconst(f))
            args = st.args[4:end]
            global nattr += 1
        end
        (fv isa Core.Builtin || fv isa Core.IntrinsicFunction) && continue
        k = findfirst(a -> erased(CC.argextype(a, ir)), args)
        k === nothing && continue
        key = fv === nothing ? CC.widenconst(f) : fv
        recv = CC.widenconst(CC.argextype(args[k], ir))
        # an operation's call at a receiver typed by the set is split: this is its fallback, past the candidates
        if fv !== nothing && settyped(recv)
            atype = Tuple{typeof(fv), Any[CC.widenconst(CC.argextype(a, ir)) for a in args]...}
            ops = ccall(:jl_declared_methods_of, Any, (Any,), typeof(fv))::Vector{Any}
            if any(om -> atype <: om.sig, ops)
                global nsplit += 1
                continue
            end
        end
        push!(get!(Vector{Site}, calls, key), Site(m, CC.widenconst(ir.stmts[i][:type]), recv))
    end
end

println("# $(root) at $(X): $(length(methods_at)) methods with an argument typed $(X); not inferred: $failed")
println("# the fallbacks of split operations (intended): $nsplit sites; calls through `Core.attributed_call`: $nattr")
println("# other dynamic calls on a value of $(X): $(sum(length, values(calls); init = 0)) sites, $(length(calls)) functions")
println("# the wrappers over $(X) (type: parameter <: bound, field): ",
        join(["$(T): $(p) <: $(Base.unwrap_unionall(T).types[findfirst(==(f), fieldnames(Base.unwrap_unionall(T)))].ub), .$(f)" for (T, p, f) in wrappers], "; "))
# the receivers' types over all sites: whether the stream is the set itself or a type over it
recvs = Dict{Any,Int}()
for sites in values(calls), s in sites
    recvs[s.recv] = get(recvs, s.recv, 0) + 1
end
println("# receivers (sites): ", join(["$(r) ($(n))" for (r, n) in first(sort(collect(recvs); by = p -> -p[2]), 8)], "; "))
println(rpad("function", 28), lpad("sites", 6), lpad("methods", 8), "   results (sites) | receivers (sites)")
for (f, sites) in first(sort(collect(calls); by = p -> -length(p[2])), nshow)
    rts = Dict{Any,Int}()
    for s in sites
        rts[s.rt] = get(rts, s.rt, 0) + 1
    end
    rs = join(["$(r) ($(n))" for (r, n) in first(sort(collect(rts); by = p -> -p[2]), 3)], ", ")
    rv = Dict{Any,Int}()
    for s in sites
        rv[s.recv] = get(rv, s.recv, 0) + 1
    end
    vs = join(["$(r) ($(n))" for (r, n) in first(sort(collect(rv); by = p -> -p[2]), 2)], ", ")
    println(rpad(string(f), 28), lpad(length(sites), 6), lpad(length(unique(s.method for s in sites)), 8), "   ", rs, " | ", vs)
end
