# E-158, a note for check 2: a method with `@nospecialize` arguments still gets a CodeInstance per
# argument type when a caller that knows the types is inferred (inference, not codegen), in a trait
# module and in a plain module alike; `Base.@nospecializeinfer` gives one. Not a TraitWorld matter.
using TraitWorld
@trait_module module TM
using TraitWorld
struct R
    f::Any
    R(@nospecialize(f)) = new(f)
end
keep(@nospecialize(f)) = R(f)
struct RI
    f::Any
    Base.@nospecializeinfer RI(@nospecialize(f)) = new(f)
end
end
module PM
struct R
    f::Any
    R(@nospecialize(f)) = new(f)
end
keep(@nospecialize(f)) = R(f)
end
function cis(f)
    n = 0
    for m in methods(f), mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            println("    ", mi.specTypes, "  owner ", ci.owner === nothing ? "plain" : ci.owner)
            n += 1
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
    return n
end
use_tm() = (TM.R(x -> 1), TM.R(x -> 2), TM.keep(x -> 3), TM.keep(x -> 4), TM.RI(x -> 5), TM.RI(x -> 6))
use_pm() = (PM.R(x -> 1), PM.R(x -> 2), PM.keep(x -> 3), PM.keep(x -> 4))
use_tm(); use_pm()
println("trait module, constructor R(@nospecialize(f)):"); a = cis(TM.R)
println("trait module, keep(@nospecialize(f)):"); b = cis(TM.keep)
println("plain module, constructor R(@nospecialize(f)):"); c = cis(PM.R)
println("plain module, keep(@nospecialize(f)):"); d = cis(PM.keep)
println("trait module, constructor RI with @nospecializeinfer:"); e = cis(TM.RI)
println("RESULT repro_nospecialize CodeInstances for four closures: trait module R $a, keep $b; plain module R $c, keep $d; trait module RI (@nospecializeinfer, two closures) $e")
