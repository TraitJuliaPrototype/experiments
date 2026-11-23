# W-171, fourth part (E-545; compiler C-169): the library's check of a pirate's membership under strict mode (traits
# §12.3) reads what the membership would replay (`jl_membership_replay_sigs`) before the declaration. A pirate's
# membership of `D` in `Named` also puts `Compiled{D}` under `Named` (the library's kept form, a pattern bounded by the
# set), and code compiled by facts calls `tag` at `Compiled{D}`: the membership changes that call's selection (`tag(::Any)`
# to `tag(::Named)`) and no other. Is it refused before the declaration (`later` false), only after it by the
# invalidation log (`later` true), or not at all?
#     julia --project=TraitWorld pirate_kept_form.jl
using TraitWorld
toplevel(q) = Core.eval(Main, Expr(:toplevel, q.args...))
toplevel(quote
    module PT                                  # the trait's owner, with a method at the trait
    using TraitWorld
    @trait Named begin
        name_of(x::Named)::String
    end
    tag(x) = "plain"
    tag(x::Named) = "named"
    end
    module PY                                  # the type's owner; it serves the operation, declares no membership
    import ..PT
    struct D end
    PT.name_of(::D) = "d"
    end
    module PL                                  # code compiled by facts, at the kept form only
    using TraitWorld
    @trait_module
    import ..PT, ..PY
    tagc(x::Core.Compiled{PY.D}) = PT.tag(x)
    end
    module P3                                  # owns neither
    using TraitWorld
    import ..PT, ..PY
    end
end)
latest(f, args...) = Base.invokelatest(f, args...)
c = Core.Compiled{PY.D}(PY.D())
println("before: tagc ", latest(PL.tagc, c))
rs = ccall(:jl_membership_replay_sigs, Any, (Any, Any), PY.D, PT.Named)
println("replay signatures: ", [(m isa Method ? m.sig : m) for m in rs])
TraitWorld.strict!(true)
e = try
    Core.eval(P3, :(@implement PT.Named PY.D)); nothing
catch err
    while err isa LoadError; err = err.error; end; err
end
TraitWorld.strict!(false)
println("declaration: ", e === nothing ? "accepted" : e isa PirateError ? "PirateError, later = $(e.later)" : repr(e))
println("after: D <: Named ", latest(<:, PY.D, PT.Named), ", tagc ", latest(PL.tagc, c))
