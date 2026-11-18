# E-312: the G2 bit (0x10) of TraitWorld's check code compiled in a session, after the session's script ran.
#   julia --project=<env> g2_of.jl <script> <args…>
script = abspath(popfirst!(ARGS))
include(script)
const TW = only(m for m in values(Base.loaded_modules) if nameof(m) === :TraitWorld)
for f in (TW._sig_alternatives, TW._check_contract!, TW._check_pattern_member, TW.check_first_use, TW._owners!, TW.sig_owners)
    for m in methods(f), mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            fl = getfield(ci, :flags, :monotonic)::UInt8
            ci.owner === nothing && println(nameof(f), " ", mi.specTypes, " facts=", (fl & 0x20) != 0,
                " G2=", (fl & 0x10) != 0, " image=", (fl & 0x04) != 0)
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
