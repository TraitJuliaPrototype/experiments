# W-19: what a package's method for its own type invalidates of the system image's code.
#   julia --startup-file=no j-invalidations.jl <probe>
# One probe per process. Prints the number of distinct instances the definition invalidates and
# the methods that hold the most of them. The probes are methods a package may define for a type
# of its own; each reaches calls that one of the patches of experiments/implementation/w19 changes.
const PROBES = Dict(
    # up/22: `promote_typejoin` at the components of an inferred union (`collect`, `broadcast`)
    "promote_typejoin"=> :(begin struct W19J end; Base.promote_typejoin(::Type{W19J}, ::Type{W19J}) = W19J end),
    # up/24: the task code's payload: `schedule` with a value of an own type
    "schedule_payload"=> :(begin struct W19K end; Base.schedule(t::Task, x::W19K; error=false) = t end),
    # up/24: `notify` with a value of an own type
    "notify_payload"  => :(begin struct W19L end; Base.notify(c::Base.GenericCondition, x::W19L, all, error) = 0 end),
    # P01: a call of `sizeof` at a `DataType` in reinterpret's padding helpers
    "sizeof_type"     => :(begin struct W19A; x::Int; end; Base.sizeof(::Type{W19A}) = 8 end),
    # P02, P03: a property read at a type value
    "getproperty_type"=> :(begin struct W19B end; Base.getproperty(::Type{W19B}, s::Symbol) = getfield(W19B, s) end),
    # P02: a call of `unwrap_unionall` at a value of unknown type
    "unwrap_unionall" => :(begin struct W19C end; Base.unwrap_unionall(x::W19C) = x end),
    # P03: a call of `typejoin` at values of unknown type
    "typejoin"        => :(begin struct W19D end; Base.typejoin(::Type{W19D}, ::Type{W19D}) = W19D end),
    # P04: DomainError's conversion of its message
    "convert_string"  => :(begin struct W19E end; Base.convert(::Type{AbstractString}, ::W19E) = "e" end),
    # P04: the three-argument TypeError's `Symbol(where)`
    "symbol_ctor"     => :(begin struct W19F end; Base.Symbol(::W19F) = :f end),
    # P04: throw_inexacterror's InexactError at a type of unknown type
    "inexacterror"    => :(begin struct W19I end; Core.InexactError(f::Symbol, ::Type{W19I}, @nospecialize(v)) = Core.InexactError(f, Int, v) end),
    # P06: a constructor of `Val{T}` for an own type `T`
    "val_ctor"        => :(begin struct W19G end; (::Type{Val{W19G}})() = 1 end),
    # P07: ImmutableDict's constructor at an own value type
    "immutabledict"   => :(begin struct W19H end; Base.ImmutableDict{Symbol,Any}(d::Base.ImmutableDict, k::Symbol, v::W19H) = d end),
)
probe = ARGS[1]
ex = PROBES[probe]
logs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
Core.eval(Main, ex)
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
insts = IdSet{Any}()
bymeth = Dict{Any,Int}()
for x in logs
    mi = x isa Core.CodeInstance ? x.def : x
    mi isa Core.MethodInstance || continue
    mi in insts && continue
    push!(insts, mi)
    m = mi.def
    k = m isa Method ? string(m.module, ".", m.name) : string(m)
    bymeth[k] = get(bymeth, k, 0) + 1
end
top = sort!(collect(bymeth); by = last, rev = true)
println(rpad(probe, 18), " invalidated instances ", lpad(length(insts), 6), "  | ",
        join(("$(k) $(v)" for (k, v) in first(top, 6)), ", "))
