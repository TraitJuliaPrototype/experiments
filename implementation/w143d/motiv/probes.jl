# W-143d (E-540): what a package's method for its own type ends of the system image's code (plain Julia's
# motivation of each patch, as ../../w19/motiv/invalidations.jl). One probe per process, a plain session:
#     julia --startup-file=no probes.jl <probe>
# Prints the distinct instances the definition invalidates, those of the methods the probe's patch changes,
# and the methods that hold the most.
const PROBES = Dict(
    # patches 01 and 02: a property read at a type value (`t.flags`, `dt.layout`, `T.a`, `T.parameters`)
    "getproperty_type" => (:(begin struct W143A end; Base.getproperty(::Type{W143A}, s::Symbol) = getfield(W143A, s) end),
        ["isbitstype", "isconcretetype", "isdispatchtuple", "isprimitivetype", "datatype_ismutationfree",
         "datatype_isidentityfree", "datatype_haspadding", "datatype_isbitsegal", "datatype_nfields",
         "datatype_fielddesc_type", "datatype_arrayelem", "datatype_layoutsize", "datatype_pointerfree", "ismutable",
         "ismutabletype", "promote_typejoin_union", "typejoin_union_tuple", "typejoin"]),
    # patch 02: a join of a type of its own
    "typejoin"         => (:(begin struct W143B end; Base.typejoin(::Type{W143B}, ::Type{W143B}) = W143B end),
        ["promote_typejoin_union", "typejoin_union_tuple"]),
    # patch 02: `promote_typejoin` of a type of its own
    "promote_typejoin" => (:(begin struct W143P end; Base.promote_typejoin(::Type{W143P}, @nospecialize(b)) = Any end),
        ["promote_typejoin_union", "typejoin_union_tuple"]),
    # patch 03: `getindex` of a tuple holding a type of its own
    "getindex_tuple"   => (:(begin struct W143C end; Base.getindex(t::Tuple{W143C, Int}, i::Int) = getfield(t, i) end),
        ["iterate"]),
    # patch 04: a `Channel`'s property set at an exception of its own
    "setproperty_channel" => (:(begin struct W143E <: Exception end; Base.setproperty!(c::Channel, s::Symbol, x::W143E) = setfield!(c, s, x) end),
        ["close"]),
    # patch 04: `notify` at a value of its own
    "notify"           => (:(begin struct W143N end; Base.notify(c::Base.GenericCondition, x::W143N, all, error) = 0 end),
        ["notify_error", "close"]),
    # patch 04: `schedule` at a value of its own
    "schedule"         => (:(begin struct W143S end; Base.schedule(t::Task, x::W143S; error = false) = t end),
        ["notify", "notify_error", "close"]),
)
probe = ARGS[1]
ex, targets = PROBES[probe]
logs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
Core.eval(Main, ex)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
insts = IdSet{Any}()
bymeth = Dict{String,Int}()
for x in logs
    mi = x isa Core.CodeInstance ? x.def : x
    mi isa Core.MethodInstance || continue
    mi in insts && continue
    push!(insts, mi)
    m = mi.def
    k = m isa Method ? string(m.name) : string(m)
    bymeth[k] = get(bymeth, k, 0) + 1
end
top = sort!(collect(bymeth); by = last, rev = true)
nt = sum(get(bymeth, t, 0) for t in targets)
println(rpad(probe, 20), " julia ", Base.GIT_VERSION_INFO.commit_short, " | invalidated instances ", lpad(length(insts), 6),
        " | of the patch's methods ", lpad(nt, 5), " (", join(("$t $(bymeth[t])" for t in targets if haskey(bymeth, t)), ", "), ")",
        " | most: ", join(("$(k) $(v)" for (k, v) in first(top, 5)), ", "))
