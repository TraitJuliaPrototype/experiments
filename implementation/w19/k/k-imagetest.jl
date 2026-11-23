# The image case of row 193 (test/precompile.jl, "memberships in package images"), standalone: packages in a
# temporary load path and depot, loaded in this session. Fails on a build without the row, passes with it.
using Test
dir = mktempdir(); depot = mktempdir()
pushfirst!(LOAD_PATH, dir); pushfirst!(DEPOT_PATH, depot)
setmacro = """
    macro set(name, params...)
        tvs = [:(\$p = TypeVar(\$(QuoteNode(p)))) for p in params]
        t = gensym(:set)
        return esc(quote
            Core.declare_global(\$__module__, \$(QuoteNode(name)), false)
            \$(Expr(:latestworld))
            let \$(tvs...)
                local \$t = Core._abstracttype(\$__module__, \$(QuoteNode(name)), Core.svec(\$(params...)))
                ccall(:jl_set_open_set, Cvoid, (Any,), \$t)
                Core._setsuper!(\$t, Any)
                Core._typebody!(false, \$t)
                Core.declare_const(\$__module__, \$(QuoteNode(name)), \$t)
            end
            \$(Expr(:latestworld))
            nothing
        end)
    end
    member!(X, S, declarer = @__MODULE__) =
        ccall(:jl_declare_membership, Any, (Any, Any, Any, Any, Any), S, X, declarer, nothing, :self)
    """
@testset "row 193" begin
include(joinpath(@__DIR__, "k-tests", "08p.jlinc"))
end
