# W-151 (D-3), E-397's control again: the definition-time check as a reading of the method at the box. The six
# methods of `w152/p2/mistakes.jl`, five with a use outside the contract, in two modules that do not refuse them:
# `Plain` as E-397 wrote them (no default), `Erasing` with the trait's default and `@erasing` (the kept forms).
# For each method: its faults at the box, each with the line of the method that passes the value. Then `Bounded`:
# the same mistakes in a module that declares `bounded`, each refused where it is defined.
#     julia --project=<TraitWorld> mistakes.jl
using TraitWorld

module Plain
using TraitWorld
@trait_module bounded = false first_seen = false
@trait ColTable begin
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end
struct Wrapped{T}; t::T; end
good(t::ColTable, i::Int) = sum(col(t, i)) / ncols(t)
spread(t::ColTable) = size(t)                 # `size` is no operation
colsum(t::ColTable) = sum(t)                  # Base's `sum` iterates
field(t::ColTable) = t.data                   # no declared field
leak(t::ColTable) = typeof(t)                 # the code depends on the type
wrap(t::ColTable) = Wrapped(t)                # stored with its type
helper(x) = length(x)
through(t::ColTable) = helper(t)              # through an unannotated function of the module
end

module Erasing
using TraitWorld
@trait_module bounded = false first_seen = false
@trait ColTable begin
    @default_dynamic
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end
struct Wrapped{T}; t::T; end
@erasing good(t::ColTable, i::Int) = sum(col(t, i)) / ncols(t)
@erasing spread(t::ColTable) = size(t)
@erasing colsum(t::ColTable) = sum(t)
@erasing field(t::ColTable) = t.data
@erasing leak(t::ColTable) = typeof(t)
@erasing wrap(t::ColTable) = Wrapped(t)
helper(x) = length(x)
@erasing through(t::ColTable) = helper(t)
end

for M in (Plain, Erasing)
    println("== ", M, ": check_definitions")
    for p in check_definitions(M)
        println("  ", replace(p, r"^(\S+) at \S*/" => s"\1 at "))
    end
    for name in (:good, :spread, :colsum, :field, :leak, :wrap, :through)
        f = getglobal(M, name)
        ms = [m for m in methods(f) if TraitWorld._at_box_checked(m)]
        for m in ms
            fs = check_at_box(m)
            println(rpad(string(name), 8), " line ", m.line, ": ", fs === nothing ? "not read" : isempty(fs) ? "bounded" :
                    join(["line $(u.line): $(u.what)" for u in fs], "; "))
        end
    end
end

println("== a module that declares `bounded`: each mistake refused where it is defined")
module Bounded
using TraitWorld
@trait_module first_seen = false
@trait ColTable begin
    @default_dynamic
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end
helper(x) = length(x)
end
for (name, ex) in ((:good, :(@erasing good(t::ColTable, i::Int) = sum(col(t, i)) / ncols(t))),
                   (:spread, :(@erasing spread(t::ColTable) = size(t))),
                   (:colsum, :(@erasing colsum(t::ColTable) = sum(t))),
                   (:field, :(@erasing field(t::ColTable) = t.data)),
                   (:leak, :(@erasing leak(t::ColTable) = typeof(t))),
                   (:through, :(@erasing through(t::ColTable) = helper(t))))
    r = try
        Core.eval(Bounded, Expr(:block, LineNumberNode(100, :defined_here), ex)); "accepted"
    catch e
        e isa TraitUseError ? "refused: " * replace(sprint(showerror, e), "\n" => " | ") : "error: " * sprint(showerror, e)
    end
    println(rpad(string(name), 8), r)
end
