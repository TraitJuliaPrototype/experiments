# E-233: what the load invalidates (Julia's invalidation log over the `using`), by cause: a method inserted that
# invalidates compiled code (the method named), or an image's edges that fail validation (the reason tag).
#     julia --project=<env> invalidations.jl CSV,DataFrames,Statistics,Dates
const PKGS = Symbol.(split(ARGS[1], ","))
invs = ccall(:jl_debug_method_invalidation, Any, (Cint,), 1)
for p in PKGS; Base.require(Main, p); end
ccall(:jl_debug_method_invalidation, Any, (Cint,), 0)
# the log: the invalidated MethodInstances (or CodeInstances; integers are depths) followed by a tag string and its cause
function tally(invs)
bytag = Dict{String,Int}(); bymeth = Dict{Any,Int}(); bymod = Dict{Any,Int}()
i = 1; pending = 0
while i <= length(invs)
    x = invs[i]
    if x isa String
        bytag[x] = get(bytag, x, 0) + pending
        if (x == "jl_method_table_insert" || x == "jl_method_table_disable") && i < length(invs) && invs[i+1] isa Method
            m = invs[i+1]; bymeth[m] = get(bymeth, m, 0) + pending
            bymod[parentmodule(m)] = get(bymod, parentmodule(m), 0) + pending; i += 1
        elseif i < length(invs) && !(invs[i+1] isa String) && (x in ("insert_backedges_callee", "verify_methods"))
            c = invs[i+1]; i += 1
            k = c isa Core.MethodInstance ? c.def : c isa Method ? c : typeof(c)
            bymeth[(x, k)] = get(bymeth, (x, k), 0) + pending
        end
        pending = 0
    elseif x isa Core.MethodInstance || x isa Core.CodeInstance
        pending += 1
    end
    i += 1
end
return bytag, bymeth, bymod
end
bytag, bymeth, bymod = tally(invs)
println("I log entries ", length(invs))
for (k, v) in sort!(collect(bytag); by = last, rev = true); println("I tag ", rpad(k, 30), v); end
for (k, v) in sort!(collect(bymod); by = last, rev = true)[1:min(end, 15)]; println("I by module of the inserted method ", rpad(string(k), 30), v); end
for (k, v) in sort!(collect(bymeth); by = last, rev = true)[1:min(end, 25)]; println("I cause ", lpad(v, 6), "  ", first(sprint(show, k), 200)); end
