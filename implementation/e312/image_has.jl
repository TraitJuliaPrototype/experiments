# E-312: does TraitWorld's image hold its check code at the signatures a session compiles, and does the
# load keep it? The CodeInstances of a few methods after `using TraitWorld`, then after the session's packages.
using TraitWorld
const TW = TraitWorld
function report(tag)
    for (f, n) in ((TW._sig_alternatives, 2), (TW._check_contract!, 7), (TW._check_pattern_member, 2), (TW.check_first_use, 2), (TW._member_hook, 2))
        for m in methods(f)
            for mi in Base.specializations(m)
                ci = isdefined(mi, :cache) ? mi.cache : nothing
                while ci !== nothing
                    fl = getfield(ci, :flags, :monotonic)::UInt8
                    println(tag, " ", nameof(f), " ", mi.specTypes, " owner=", ci.owner === nothing ? "-" : "x",
                            " world=", ci.min_world, ":", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
                            " facts=", (fl & 0x20) != 0, " image=", (fl & 0x04) != 0, " native=", (fl & 0x08) != 0,
                            " invoke=", ci.invoke != C_NULL)
                    ci = isdefined(ci, :next) ? ci.next : nothing
                end
            end
        end
    end
end
report("load")
for p in Symbol.(ARGS); @eval using $p; end
report("after")
