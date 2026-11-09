# The typemap report: how many methods a lookup must test one by one. Julia's method table is a tree
# of levels, one per argument position; at each level a method is filed under its argument's type name
# (indexed), under `Any`, or in the level's linear list, which every lookup reaching the level walks,
# testing each entry by type intersection. A method whose signature holds an open set is filed in the
# linear list of the level it reaches (src/typemap.c, `jl_has_open_set_in`), so with `IO` a set every
# `show(io::IO, …)` is in one list (found 2026-11-09 by the profile of the goal's load: validation's
# `verify_call` 2.8 of 5.0 s, in that list's visitor).
#     julia-unified/julia --startup-file=no [--project=<env>] experiments/unification/audit/typemap_linear.jl [Pkg,…] [n]
# Loads the packages, then counts the methods (valid in the latest world) by where they are filed, and
# lists the functions whose linear lists are longest. A report: it asserts nothing.
pkgs = length(ARGS) >= 1 && !isempty(ARGS[1]) ? split(ARGS[1], ',') : String[]
nshow = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30
for p in pkgs
    Core.eval(Main, :(using $(Symbol(p))))
end

has_set(t) = ccall(:jl_has_open_set, Cint, (Any,), t) != 0   # whether a type mentions an open set (compiler §4.8)
fname(sig) = (u = Base.unwrap_unionall(sig); u isa DataType && length(u.parameters) >= 1 ? u.parameters[1] : nothing)

counts = Dict(:indexed => 0, :any => 0, :linear => 0)
linear_set = 0
bylist = Dict{Any,Tuple{Int,Int}}()   # function type => (entries in linear lists, of which with an open set)
longest = Pair{Any,Int}[]            # (function, length of one linear list)

function visit_entries(e, where_)
    n = 0
    while e isa Core.TypeMapEntry
        if e.max_world == typemax(UInt)
            n += 1
            counts[where_] += 1
            if where_ === :linear
                s = has_set(e.sig)
                s && (global linear_set += 1)
                f = fname(e.sig)
                a, b = get(bylist, f, (0, 0))
                bylist[f] = (a + 1, b + s)
            end
        end
        e = isdefined(e, :next) ? e.next : nothing
    end
    return n
end

function visit(x, where_)
    if x isa Core.TypeMapLevel
        for fld in (:arg1, :targ, :name1, :tname)
            visit(getfield(x, fld), :indexed)
        end
        l = x.list
        if l isa Core.TypeMapEntry
            first_sig = l.sig
            n = visit_entries(l, :linear)
            n > 1 && push!(longest, fname(first_sig) => n)
        end
        visit(x.any, :any)
    elseif x isa Memory
        for i in 2:2:length(x)
            isassigned(x, i) || continue
            visit(x[i], where_)
        end
    elseif x isa Core.TypeMapEntry
        visit_entries(x, where_)
    end
end

visit(Core.methodtable.defs, :indexed)
total = sum(values(counts))
println("# the typemap report: world $(Base.get_world_counter()), packages $(isempty(pkgs) ? "none" : join(pkgs, ", "))")
println("methods valid in the latest world: $total; indexed $(counts[:indexed]), under Any $(counts[:any]), in linear lists $(counts[:linear]) ($linear_set with an open set)")
println("# the functions with the most methods in linear lists (entries, of which with an open set):")
for (f, (a, b)) in first(sort(collect(bylist); by = x -> x[2][1], rev = true), nshow)
    println(lpad(a, 7), lpad(b, 7), "  ", f)
end
println("# the longest single linear lists:")
for (f, n) in first(sort(longest; by = last, rev = true), 10)
    println(lpad(n, 7), "  ", f)
end
