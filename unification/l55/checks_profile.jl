# E-317: what a session spends checking a pattern's members (lowering L-55): the session profiled by
# class (../w121/session_profile.jl, the class "member check" is TraitWorld.check_first_use), then the
# members this session checked, from TraitWorld's table of answers.
#   SCRIPT=<script> CSVF=<csv> PNGF=<png> julia --project=<env> checks_profile.jl
include(joinpath(@__DIR__, "..", "w121", "session_profile.jl"))
TW = only(m for m in values(Base.loaded_modules) if nameof(m) === :TraitWorld)
ks = collect(keys(TW._CHECKED))
println("members checked in this session: ", length(ks))
for k in first(sort(ks; by = string), 40)
    println("    ", k)
end
