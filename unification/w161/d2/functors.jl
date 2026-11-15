# W-161, E-500: the callable structs of loaded code, and how each can be passed at a `Callable` argument (GT-32,
# open issue 227). Under D-2 every `Function` is a member of every `Callable{A, S}`; a callable struct that is no
# `Function` is a member only by its declaration (`@implement Callable T`).
# A functor type: a type, not a function's own type, with a call method `(x::T)(…)`. Each is counted once,
# by the package that defines the type, in one of three kinds:
#   function   the type subtypes `Function` (Julia's idiom): a member
#   declared   the type is a member of `Callable` by its declaration
#   neither    the type cannot be passed where `Callable` is asked
#     julia --project=<env> functors.jl <package>...        (prints a table; `-v` lists every `neither`)
verbose = "-v" in ARGS
pkgs = filter(!=("-v"), ARGS)
for p in pkgs; Core.eval(Main, Meta.parse("using $p")); end
const CN = Base.unwrap_unionall(Core.Callable).name
root(mod::Module) = nameof(Base.moduleroot(mod))
# the type a call method's first argument names, or nothing (a function's own type, a constructor, a Union)
function functor_type(m::Method)
    sig = Base.unwrap_unionall(m.sig)
    sig isa DataType && length(sig.parameters) >= 1 || return nothing
    t = sig.parameters[1]
    t isa TypeVar && (t = t.ub)
    t = Base.unwrap_unionall(t)
    t isa DataType || return nothing
    t.name === Base.unwrap_unionall(Type).name && return nothing          # a constructor
    startswith(string(t.name.name), "#") && return nothing                # a function's or a closure's own type
    t === Any && return nothing
    return t
end
kinds = Dict{Symbol,Dict{Symbol,Int}}()
neither = Dict{Symbol,Vector{String}}()
seen = Set{Core.TypeName}()
Base.visit(Core.methodtable) do m
    t = functor_type(m)
    t === nothing && return
    t.name in seen && return
    push!(seen, t.name)
    w = t.name.wrapper
    k = w <: Function ? :function : (w <: Core.Callable || t <: Core.Callable) ? :declared : :neither
    r = root(t.name.module)
    d = get!(() -> Dict(:function => 0, :declared => 0, :neither => 0), kinds, r)
    d[k] += 1
    k === :neither && push!(get!(Vector{String}, neither, r), string(t.name.module, ".", t.name.name))
end
println("package | function | declared | neither")
for r in sort!(collect(keys(kinds)))
    d = kinds[r]
    println(r, " | ", d[:function], " | ", d[:declared], " | ", d[:neither])
end
tot = Dict(k => sum(d[k] for d in values(kinds)) for k in (:function, :declared, :neither))
println("all | ", tot[:function], " | ", tot[:declared], " | ", tot[:neither])
if verbose
    for r in sort!(collect(keys(neither)))
        println("# ", r, ": ", join(sort!(neither[r]), ", "))
    end
end
