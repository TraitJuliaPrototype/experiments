# E-299 (W-123, stage 1's item 3): where validation spends its time in one package's load. The packages in
# VP_BEFORE are loaded first (default "TraitWorld Tables CSV"); then VP_TARGET (default DataFrames) is loaded
# under the profiler with C frames. The main thread's samples under validation (load_profile.jl's class) are
# tallied by function: self (the leaf frame) and inclusive (anywhere on the stack). Then the edges of the
# target's own instances (its modules' methods' specializations, the CodeInstances valid now) are counted by kind.
# Usage: julia --project=<env> validation_profile.jl
using Profile
const BEFORE = split(get(ENV, "VP_BEFORE", "TraitWorld Tables CSV"))
const TARGET = get(ENV, "VP_TARGET", "DataFrames")
for p in BEFORE
    Core.eval(Main, :(using $(Symbol(p))))
end
Profile.init(n = 10^7, delay = 0.0005)
t0 = time()
Profile.@profile Core.eval(Main, :(using $(Symbol(TARGET))))
println("load of $TARGET after $(join(BEFORE, ", ")): ", round(time() - t0, digits = 3), " s (profiled)")

const VAL = ["verify_method_graph", "jl_verify", "verify_call", "_insert_backedges", "insert_backedges", "verify_methods"]
function tally()
    data, lidict = Profile.retrieve()
    self = Dict{String,Int}(); incl = Dict{String,Int}()
    total = nval = 0
    start = 1; n = length(data); i = 3
    while i <= n
        if data[i] == 0 && data[i-1] == 0 && data[i-2] in 1:3
            tid = data[i-5]; sleeping = data[i-2] != 1
            frames = @view data[start:i-6]
            start = i + 1
            if tid == 1 && !sleeping && !isempty(frames)
                total += 1
                names = String[]
                for ip in frames, fr in get(lidict, ip, Base.StackTraces.StackFrame[])
                    push!(names, string(fr.func, fr.from_c ? " [C]" : ""))
                end
                if any(nm -> any(k -> occursin(k, nm), VAL), names)
                    nval += 1
                    self[names[1]] = get(self, names[1], 0) + 1
                    for nm in unique(names)
                        incl[nm] = get(incl, nm, 0) + 1
                    end
                end
            end
            i += 3
        else
            i += 1
        end
    end
    return total, nval, self, incl
end
total, nval, self, incl = tally()
println("samples: $total on the main thread, $nval under validation ($(round(100nval / max(total, 1), digits = 1)) %)")
println("-- self, top 25 (share of validation's samples)")
for (k, v) in first(sort(collect(self); by = last, rev = true), 25)
    println(lpad(round(100v / nval, digits = 1), 6), " %  ", k)
end
println("-- inclusive, top 45")
for (k, v) in first(sort(collect(incl); by = last, rev = true), 45)
    println(lpad(round(100v / nval, digits = 1), 6), " %  ", k)
end

# the target's own instances and their edges, by kind
function edge_kinds(mod::Module)
    kinds = Dict{String,Int}(); ncis = 0
    mods = Set{Module}([mod])
    for nm in names(mod; all = true)
        isdefined(mod, nm) || continue
        v = getfield(mod, nm)
        v isa Module && parentmodule(v) === mod && v !== mod && push!(mods, v)
    end
    seen = Set{Any}()
    Base.visit(Core.methodtable) do m
        m.module in mods || return
        for mi in Base.specializations(m)
            mi === nothing && continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while ci !== nothing
                if !(ci in seen) && ci.max_world == typemax(UInt)
                    push!(seen, ci); ncis += 1
                    e = ci.edges
                    j = 1
                    while j <= length(e)
                        x = e[j]
                        k = x isa Core.CodeInstance ? "CodeInstance" : x isa Core.MethodInstance ? "MethodInstance" :
                            x isa Int ? "call by signature (count + sig + matches)" : x isa Core.MembershipCell ? "MembershipCell" :
                            x isa Core.MembershipEntry ? "MembershipEntry" : x isa Core.Binding ? "Binding" :
                            x isa Type ? "invoke signature" : string(typeof(x))
                        kinds[k] = get(kinds, k, 0) + 1
                        j += x isa Int ? 2 + abs(x) : (x isa Type ? 2 : 1)
                    end
                end
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
        end
    end
    return ncis, kinds
end
ncis, kinds = edge_kinds(getfield(Main, Symbol(TARGET)))
println("-- $TARGET's own instances valid now: $ncis; their edges by kind")
for (k, v) in sort(collect(kinds); by = last, rev = true)
    println(lpad(v, 8), "  ", k)
end
