# W-157: the methods, outside Base and Core, that stage 5's patches would no longer reach. The patches call
# Base's own helpers through `invoke` at their own signature, build exceptions with `new`, and write a task's
# field with `setfield!`; a package's method of those functions or constructors, at its own type, would have
# intercepted the call before. The patches change plain code's behaviour only where such a method exists.
#     julia --project=env_forks diag/intercept.jl <package>...     (after loading the packages)
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const FUNCS = Any[typejoin, Base.typesplit, Base.tailjoin, Base.full_va_len, Base.promote_typejoin, Base._promote_typesubtract,
                  Base.rewrap_unionall, Base.unwrapva, supertype, Core.throw_inexacterror, Base.string_index_err, (!==),
                  UnionAll, InexactError, DomainError, StringIndexError, TypeError, Val]
own(m::Method) = nameof(Base.moduleroot(m.module)) in (:Base, :Core)
n = 0
for f in FUNCS
    for m in methods(f)
        own(m) && continue
        global n += 1; println("  ", f, ": ", m.sig, " in ", m.module)
    end
end
# setproperty! with a `Task` first argument, outside Base and Core
for m in methods(setproperty!)
    own(m) && continue
    b = Base.unwrap_unionall(m.sig)
    b isa DataType && length(b.parameters) >= 2 || continue
    p = b.parameters[2]; p isa TypeVar && (p = p.ub)
    p isa Type && Task <: p && p !== Any || continue
    global n += 1; println("  setproperty!: ", m.sig, " in ", m.module)
end
println("# intercept | julia ", Base.GIT_VERSION_INFO.commit_short, " | loaded: ", join(ARGS, " "), " | methods the patches would not reach: ", n)
