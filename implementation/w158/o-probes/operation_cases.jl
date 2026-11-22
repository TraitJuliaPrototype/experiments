# W-158 (traits T-162, §12.2): the cases of "a trait's operation is not owner-only by the default", each with what the
# library does. Run with the project of the library: julia --project=. operation_cases.jl
using TraitWorld
println("TraitWorld ", pathof(TraitWorld))
const CC = Base.Compiler
function thrown(ex)
    try
        top(ex); return "accepted"
    catch e
        while e isa LoadError; e = e.error; end
        return string(nameof(typeof(e)), ": ", first(replace(sprint(showerror, e), "\n" => " "), 230))
    end
end
top(q) = Core.eval(Main, Expr(:toplevel, (q isa Expr && q.head === :block ? q.args : Any[q])...))
row(what, r) = println(rpad(what, 78), " | ", r)
# the code compiled by facts for `f` at `T` in the latest world: its result type and its G2 bit
function code_of(f, T)
    for m in methods(f), mi in Base.specializations(m)
        (mi isa Core.MethodInstance && mi.specTypes === Tuple{typeof(f), T.parameters...} && isdefined(mi, :cache)) || continue
        ci = mi.cache
        while true
            ci.max_world == typemax(UInt) && (ci.flags & 0x20) != 0 && return (ci.rettype, (ci.flags & 0x10) != 0)
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
    return nothing
end
top(quote
    module OL
    using TraitWorld
    @trait_module
    export OS
    @trait OS begin
        oa(s::OS)::Float64                      # not exported
    end
    struct S0 end
    @implement OS S0 begin
        oa(s) = 1.0
    end
    g(v::Vector{Any}) = oa(v[1])                # a call at a value of a type the code does not know
    g(Any[S0()])                                # compiled in the module's body, before its end
    end
end)
const OLm = Main.OL
row("in the module's body: g(::Vector{Any}) compiled while oa was owner-only", string(code_of(OLm.g, Tuple{Vector{Any}})))
row("after the module's end: oa owner-only to the compiler", string(CC.is_owner_only(typeof(OLm.oa)), "; public ", Base.ispublic(OLm, :oa)))
row("a member's module adds oa's method for its own type, in a block", thrown(quote
    module M1; using TraitWorld, ..OL; @trait_module
    struct Sq; s::Float64; end
    @implement OS Sq begin oa(q) = q.s^2 end
    end end))
row("  g's code compiled in the body afterwards (ended by the member's method?)", string(code_of(OLm.g, Tuple{Vector{Any}})))
row("  pirate reports so far", string(length(TraitWorld.PIRATE_REPORTS)))
row("a module adds oa's method for its own type that is no member", thrown(quote
    module M2; using TraitWorld, ..OL; @trait_module
    struct NotMember end
    OL.oa(::NotMember) = 0.0
    end end))
row("a third module: oa's method for a type it does not own (classic pirate)", thrown(quote
    module M3; using TraitWorld, ..OL; @trait_module
    OL.oa(x::Int) = 1.0
    end end))
row("a third module: a membership of OS for a type it does not own (pirate's membership)", thrown(quote
    module M4; using TraitWorld, ..OL; @trait_module
    @implement OS Int begin oa(x) = 1.0 end
    end end))
row("a third module: oa's method at the trait itself", thrown(quote
    module M5; using TraitWorld, ..OL; @trait_module
    OL.oa(s::OS, k::Int) = 1.0
    end end))
# another package's trait that names a trait module's internal function as its operation
top(quote
    module IA; using TraitWorld; @trait_module
    helper(x) = 1                               # internal: owner-only
    end
end)
row("another module's trait names IA's internal helper as its operation", thrown(quote
    module IB; using TraitWorld, ..IA; @trait_module
    export BX
    @trait BX begin
        IA.helper(s::BX)::Int                   # another module's internal function as the operation
    end
    end end))
row("  IA's helper owner-only to the compiler after IB", string(Base.Compiler.is_owner_only(typeof(Main.IA.helper))))
# an operation closed by @owner_only
top(quote
    module CL; using TraitWorld; @trait_module
    export CS
    @trait CS begin
        ca(s::CS)::Float64
    end
    @owner_only ca
    end
end)
row("@owner_only ca: a member's method in a block", thrown(quote
    module M7; using TraitWorld, ..CL; @trait_module
    struct T7 end
    @implement CS T7 begin ca(t) = 1.0 end
    end end))
# exported later in the module's body: no conflict with the module's end
row("an operation exported after its @trait", thrown(quote
    module EL; using TraitWorld; @trait_module
    @trait ES begin
        ea(s::ES)::Int
    end
    export ES, ea
    end end))
