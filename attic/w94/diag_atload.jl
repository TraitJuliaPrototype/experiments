# W-94: what `_member_fold(AtLoad(), …)` does while an image's code is validated. A tracing copy of
# `_member_fold_at_load` replaces TraitWorld's in this session only (no file is edited), then the
# packages load.     julia --project=<env> diag_atload.jl [Pkg,Pkg,…]
using TraitWorld
const TW = TraitWorld
@eval TW function _member_fold_at_load(reg::Base.RefValue{IdDict{Any,Any}}, @nospecialize(X), @nospecialize(U))
    println(stderr, "AtLoad ", X, " at ", U, ": world ", Base.tls_world_age(), " latest ", Base.get_world_counter(),
            "; decision world ", _decision_world())
    b = get(reg[], U, nothing)
    b isa Builder && (println(stderr, "  registry hit"); return b)
    w = _decision_world()
    ms = Base._methods_by_ftype(Tuple{typeof(_member_record),Type{X},Type{U},Any}, -1, w)
    println(stderr, "  records: ", ms isa Vector ? length(ms) : ms)
    if ms isa Vector
        for m in ms
            K = Base.unwrap_unionall(m.method.sig).parameters[4]
            r = Base.invoke_in_world(w, _member_record, X, U, K.instance)
            println(stderr, "  record ", K, " holds ", _record_holds(r, w))
            for j in eachindex(r.sigs)
                now = _selected_methods(r.sigs[j], w)
                now == r.methods[j] && continue
                println(stderr, "    ", r.sigs[j], "\n      then ", r.methods[j], "\n      now  ", now)
            end
        end
    end
    b = _member_from_record!(reg, X, U)
    b isa Builder && (println(stderr, "  from record"); return b)
    r = try
        _member_fix!(reg, X, U)
    catch e
        println(stderr, "  fix threw ", sprint(showerror, e)[1:min(end, 300)])
        nothing
    end
    println(stderr, "  fixed again: ", typeof(r))
    return r
end
for p in Symbol.(split(get(ARGS, 1, "Tables,CSV"), ","))
    println(stderr, "--- loading ", p)
    Base.require(Main, p)
end
