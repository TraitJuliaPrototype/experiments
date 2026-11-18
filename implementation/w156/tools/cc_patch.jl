# Lays the named top-level definitions of a Compiler source file over the session's Base.Compiler, to try a
# change to inference or the inliner before a build. Usage, in a session:
#   include("cc_patch.jl"); cc_patch(file, [:name, ...])
# A definition is taken where its name (a function's, a const's, a struct's) is in the list.
const _CC = Base.Compiler
function _defname(ex)
    ex isa Expr || return nothing
    ex.head === :macrocall && return _defname(ex.args[end])
    ex.head in (:function, :(=)) || ex.head === :const || return nothing
    ex.head === :const && return _defname(ex.args[1])
    sig = ex.args[1]
    while sig isa Expr && sig.head in (:where, :(::))
        sig = sig.args[1]
    end
    sig isa Symbol && return sig
    sig isa Expr && sig.head === :call || return nothing
    f = sig.args[1]
    f isa Symbol && return f
    return nothing
end
function cc_patch(file::AbstractString, names::Vector{Symbol}; mod::Module = _CC)
    ast = Meta.parseall(read(file, String); filename = file)
    n = 0
    for ex in ast.args
        _defname(ex) in names || continue
        Core.eval(mod, ex)
        n += 1
    end
    println(stderr, "cc_patch: ", n, " definitions from ", basename(file))
    return n
end
