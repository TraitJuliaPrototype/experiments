# The set-root report: how much of a load's invalidation starts at an instance compiled at a set. Code
# compiled once at a set (`IO`) calls a function that is not one of the set's operations statically, into
# the instance of Base's generic method at the set (`seekstart(::IO)`); a member's own, more specific
# method then invalidates that instance and every caller above it. Found 2026-11-09 (E-335): the
# goal's read regenerated 1.4 s of machine code for code invalidated so.
#     julia-unified/julia --startup-file=no --project=<env> experiments/unification/audit/set_roots.jl Pkg,… [n]
# Loads the packages with the invalidation log on; for each method insertion, the instances it
# invalidated are attributed to its root (the replaced instance) where the root has an argument that
# is an open set. Lists the roots, most instances first. A report: it asserts nothing.
log = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in split(ARGS[1], ',')
    Core.eval(Main, :(using $(Symbol(p))))
end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 25

isset(p) = p isa Type && ccall(:jl_is_open_set, Cint, (Any,), p) != 0
atset(T) = any(isset, Base.unwrap_unionall(T).parameters)
byroot = Dict{Any,Int}(); total = 0; underset = 0
i = 1; cur = Any[]
while i <= length(log)
    x = log[i]
    if x isa Core.MethodInstance && i < length(log) && log[i+1] isa Int32
        push!(cur, x); global i += 2
    elseif i < length(log) && log[i+1] == "jl_method_table_insert"
        # the cause: the replaced instance (the root) or, last, the method inserted
        global total += length(cur)
        if x isa Core.MethodInstance && atset(x.specTypes)
            global underset += length(cur)
            byroot[x.specTypes] = get(byroot, x.specTypes, 0) + length(cur)
        end
        empty!(cur); global i += 2
    else
        global i += 1
    end
end
println("# the set-root report: packages $(ARGS[1])")
println("instances invalidated at insertions: $total; under a root with an argument that is a set: $underset")
for (k, v) in first(sort(collect(byroot); by = last, rev = true), nshow)
    println(lpad(v, 6), "  ", first(string(k), 160))
end
