# The testsets for rows 181, 182 and 185 to 195 of the inventory, as they go into Julia's `test/subtype.jl`
# (seventh part of W-19), run standalone: on a build without the rows (the sixth part's S3) the cases of each row
# fail, on `next` 3e9c193025 and on the series' head they pass. Run:
#     <tree>/julia --startup-file=no experiments/implementation/w19/k/k-rowtests.jl [02d.jl ...]
# A build without row 185 stops at `vaqa` (a typeassert folded to `unreachable`): run each file alone there.
# One block per part; each block's text is the one the part's commit adds (`k-tests/<part>.jl`).
module RowTests
using Test

macro set(name, params...)
    tvs = [:($p = TypeVar($(QuoteNode(p)))) for p in params]
    t = gensym(:set)
    return esc(quote
        Core.declare_global($__module__, $(QuoteNode(name)), false)
        $(Expr(:latestworld))
        let $(tvs...)
            local $t = Core._abstracttype($__module__, $(QuoteNode(name)), Core.svec($(params...)))
            ccall(:jl_set_open_set, Cvoid, (Any,), $t)
            Core._setsuper!($t, Any)
            Core._typebody!(false, $t)
            Core.declare_const($__module__, $(QuoteNode(name)), $t)
        end
        $(Expr(:latestworld))
        nothing
    end)
end
member!(@nospecialize(X), @nospecialize(S)) =
    ccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any), S, X, @__MODULE__, nothing, :self)
world() = Base.get_world_counter()

for f in (isempty(ARGS) ? sort(readdir(joinpath(@__DIR__, "k-tests"))) : ARGS)
    (endswith(f, ".jl") || (endswith(f, ".jlx") && !isempty(ARGS))) || continue
    println("== ", f)
    try
        @testset "$f" begin
            include(joinpath(@__DIR__, "k-tests", f))
        end
    catch e
        println("STOPPED in ", f, ": ", sprint(showerror, e)[1:min(end, 300)])
    end
end
end
