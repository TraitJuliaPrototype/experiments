# E-312: the system image's `_growend!(::Vector{String}, ::Int64)`: its edges, its flags, its debug info
mi = Base.method_instance(Base._growend!, (Vector{String}, Int64))
ci = mi.cache
while ci !== nothing
    fl = getfield(ci, :flags, :monotonic)::UInt8
    println("owner=", ci.owner === nothing ? "-" : ci.owner, " flags=", fl, " G2=", (fl & 0x10) != 0, " image=", (fl & 0x04) != 0,
            " debuginfo=", isdefined(ci, :debuginfo), " world=", ci.min_world, " nedges=", length(ci.edges))
    for e in ci.edges; println("    ", e isa Core.CodeInstance ? ("CI ", Base.Compiler.get_ci_mi(e).specTypes, " G2=", (getfield(e, :flags, :monotonic) & 0x10) != 0) : e); end
    global ci = isdefined(ci, :next) ? ci.next : nothing
end
