# E-406, the methods whose box cannot be formed (`box_signature` is nothing), with why the check does not read them.
#     CHECK_ROOTS=… julia --project=<env> notformed.jl <package>...
using TraitWorld
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const ROOTS = Tuple(Symbol.(split(ENV["CHECK_ROOTS"], ",")))
for m0 in values(Base.loaded_modules), M in (nameof(m0) in ROOTS ? [m0; [getglobal(m0, n) for n in names(m0; all = true) if isdefined(m0, n) && getglobal(m0, n) isa Module && parentmodule(getglobal(m0, n)) === m0 && getglobal(m0, n) !== m0]] : Module[])
    for name in names(M; all = true)
        isdefined(M, name) || continue
        f = try getglobal(M, name) catch; continue end
        (f isa Function || f isa Type) || continue
        for m in methods(f)
            m.module === M && TraitWorld._at_box_checked(m) && TraitWorld.box_signature(m) === nothing || continue
            println("  ", M, ".", m.name, " [", basename(string(m.file)), ":", m.line, "]  ", m.sig)
        end
    end
end
