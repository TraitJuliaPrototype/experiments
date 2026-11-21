# T-160: every message of ownership and strict mode, for the two kinds of pirate: the classic one (a method of a
# function the definer does not own, for types it does not own) and the owner-only one (a method of another
# module's owner-only function, for the definer's own type). MODE=default (the warnings, `no_pirates`) or strict.
using TraitWorld, Test
mode = get(ENV, "MODE", "default")
msg(e) = e isa Exception ? sprint(showerror, e) : string(e)
function thrown(ex)
    try
        Core.eval(Main, ex isa Expr && ex.head === :block ? Expr(:toplevel, ex.args...) : ex); nothing
    catch e
        while e isa LoadError; e = e.error; end
        e
    end
end
function show_case(name, ex)
    logs, e = Test.collect_test_logs() do
        thrown(ex)
    end
    println("CASE ", name, ": ", e === nothing ? "no error" : nameof(typeof(e)))
    e === nothing || println("  ERROR: ", replace(msg(e), "\n" => "\n         "))
    for l in logs
        l.level >= Base.CoreLogging.Warn && println("  WARN:  ", replace(string(l.message), "\n" => "\n         "))
    end
end

# the owner: a trait module whose `weight` is owner-only (neither exported nor public), used by code compiled by facts
module Tally
using TraitWorld
@trait_module
export tally
weight(x) = 1
function tally(xs::Vector{Any})
    n = 0
    for x in xs
        n += weight(x)
    end
    return n
end
end
using .Tally
# a trait whose operation is owner-only: not exported (a trait module's default)
module Shapes
using TraitWorld
@trait_module
export Shape
@trait Shape begin
    hidden_area(s::Shape)::Float64
end
total(xs::Vector{Any}) = sum(x -> hidden_area(x), xs; init = 0.0)
end
# an owner whose function is `@owner_only` by declaration, and exported
module Own
using TraitWorld
@trait_module
export score
score(x) = 0
@owner_only score
useit(xs::Vector{Any}) = (n = 0; for x in xs; n += score(x); end; n)
end
using .Own
# code compiled by facts that a classic pirate of Base's `abs2(::Float64)` ends (as docs-examples/strict.jl)
module Norms
using TraitWorld
@trait_module
export sq
sq(v::Vector{Float64}) = (s = 0.0; for x in v; s += abs2(x); end; s)
end
using .Norms
Tally.tally(Any[1, "a"]); Shapes.total(Any[]); Own.useit(Any[1]); sq([1.0, 2.0])
mode == "strict" && TraitWorld.strict!(true)

struct Heavy; w::Int; end
show_case("owner-only, at the prompt (Main), own type", :(Tally.weight(h::Heavy) = h.w))
show_case("owner-only, in a trait module (no_pirates), own type", :(module M1
    using TraitWorld, ..Tally
    @trait_module
    struct Mine end
    Tally.weight(::Mine) = 0
    end))
show_case("classic, in a trait module (no_pirates)", :(module M2
    using TraitWorld
    @trait_module
    Base.sum(x::Vector{Int8}) = 0
    end))
show_case("owner-only operation, @implement block in a trait module", :(module M3
    using TraitWorld, ..Shapes
    @trait_module
    struct Sq; s::Float64; end
    @implement Shape Sq begin
        hidden_area(q) = q.s^2
    end
    end))
show_case("owner-only operation, method then @implement in a trait module", :(module M4
    using TraitWorld, ..Shapes
    @trait_module
    struct Sq2; s::Float64; end
    Shapes.hidden_area(q::Sq2) = q.s^2
    @implement Shape Sq2
    end))
show_case("@owner_only declared and exported, a method in a trait module", :(module M5
    using TraitWorld, ..Own
    @trait_module
    struct Mine5 end
    Own.score(::Mine5) = 1
    end))
show_case("@owner_only declared and exported, a method at the prompt", :((struct Mine6 end; Own.score(::Mine6) = 1)))
show_case("classic, a module at the prompt that ends code compiled by facts", :(module Meddler
    Base.abs2(x::Float64) = 2.0 * x * x
    end))
mode == "strict" && TraitWorld.strict!(false)
