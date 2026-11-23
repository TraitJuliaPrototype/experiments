# project: TraitWorld
# Gate (compiler §5.5, §10.2; traits §12.3; E-545, C-169): what a membership would replay names the patterns bounded by
# the set as the walk replays them: a pirate's membership of `D` in `Named` whose only change to code compiled by facts
# is at the kept form `Compiled{D}` (a call of `tag`, `tag(::Any)` before, `tag(::Named)` after) is refused by strict
# mode before it is declared (`later` false), and `jl_membership_replay_sigs` lists `tag`'s method at the kept form. A
# candidate for `gates/`; fails on `next` 0bbd759c13.
#     julia --project=TraitWorld n57_pirate_kept_form.jl
using TraitWorld
toplevel(q) = Core.eval(Main, Expr(:toplevel, q.args...))
toplevel(quote
    module PT57
    using TraitWorld
    @trait Named begin
        name_of(x::Named)::String
    end
    tag(x) = "plain"
    tag(x::Named) = "named"
    end
    module PY57
    import ..PT57
    struct D end
    PT57.name_of(::D) = "d"
    end
    module PL57
    using TraitWorld
    @trait_module
    import ..PT57, ..PY57
    tagc(x::Core.Compiled{PY57.D}) = PT57.tag(x)
    end
    module P357
    using TraitWorld
    import ..PT57, ..PY57
    end
end)
latest(f, args...) = Base.invokelatest(f, args...)
c = Core.Compiled{PY57.D}(PY57.D())
@assert latest(PL57.tagc, c) == "plain"
rs = ccall(:jl_membership_replay_sigs, Any, (Any, Any), PY57.D, PT57.Named)::Vector{Any}
sigs = [rs[i+1] for i in 1:2:length(rs)-1 if rs[i] === which(PT57.tag, Tuple{PT57.Named})]
@assert any(s -> s isa Type && Tuple{typeof(PT57.tag), Core.Compiled{PY57.D}} <: s, sigs) "the replays at the kept form: $sigs"
TraitWorld.strict!(true)
e = try
    Core.eval(P357, :(@implement PT57.Named PY57.D)); nothing
catch err
    while err isa LoadError; err = err.error; end; err
finally
    TraitWorld.strict!(false)
end
@assert e isa PirateError && !e.later "refused before the declaration: $(repr(e))"
@assert !latest(<:, PY57.D, PT57.Named) && latest(PL57.tagc, c) == "plain"
println("n57_pirate_kept_form: OK")
