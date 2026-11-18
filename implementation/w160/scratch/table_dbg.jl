include(joinpath(@__DIR__, "..", "check", "edit_table.jl"))
f = TC.summarize
for m in methods(f); println(m.sig, " forwarder=", TraitWorld._is_forwarder(m), " checked=", TraitWorld._at_box_checked(m), " bounded=", TraitWorld._bounded(m)); end
println("erases: ", TraitWorld.erases(TC.Column), " ", TraitWorld.erases(TC.Column{Float64}))
for m in methods(f); TraitWorld._at_box_checked(m) && println(TraitWorld.box_signature(m), " => ", TraitWorld.check_at_box(m)); end
mi = Base.method_instance(Tuple{typeof(f), typeof(COL), String}); println(mi.specTypes)
