# E-406 (W-151, D-3): `check_definitions` (the reading at the box) over the trait modules of the packages given, as
# E-397 compared them. Loading the packages is itself the check that each port's methods pass the `bounded`
# refusal that reads the box. Prints, per module, the methods read and every fault.
#     CHECK_ROOTS=TraitTables,TraitCSV julia --project=<env> ports.jl <package>...
using TraitWorld
for p in ARGS; Core.eval(Main, Meta.parse("using $p")); end
const ROOTS = Tuple(Symbol.(split(ENV["CHECK_ROOTS"], ",")))
mods = Module[]
function allmods!(M)
    M in mods && return; push!(mods, M)
    for n in names(M; all = true)
        isdefined(M, n) || continue
        x = try getglobal(M, n) catch; continue end
        x isa Module && parentmodule(x) === M && x !== M && allmods!(x)
    end
end
for m in values(Base.loaded_modules); nameof(m) in ROOTS && allmods!(m); end
total = 0; read_ = 0; notformed = 0; faults = 0
for M in sort(mods; by = string)
    n = 0; nf = 0; lines = String[]
    for name in names(M; all = true)
        isdefined(M, name) || continue
        f = try getglobal(M, name) catch; continue end
        (f isa Function || f isa Type) || continue
        for m in methods(f)
            m.module === M || continue
            TraitWorld._at_box_checked(m) || continue
            global total += 1
            fs = check_at_box(m)
            if fs === nothing; nf += 1; continue; end
            n += 1
            for u in fs
                push!(lines, string("    ", m.name, " [", basename(string(m.file)), ":", u.line, "]",
                                    TraitWorld._bounded_option(m) === false ? " @unbounded" : "", ": ", first(u.what, 220)))
            end
        end
    end
    global read_ += n; global notformed += nf; global faults += length(lines)
    (n + nf) == 0 && continue
    println(M, ": methods at a trait read ", n, " (not formed ", nf, "), faults ", length(lines))
    foreach(println, lines)
end
println("roots ", join(ROOTS, ","), " | modules ", length(mods), " | methods at a trait ", total, ", read ", read_, ", not formed ", notformed, " | faults ", faults)
