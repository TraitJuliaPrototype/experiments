# E-440 (W-160 (c); compiler §6.7, D-3, C-115): what an edit of a method costs in a module that declares
# `bounded`, where the check reads the method's instance at the box from Julia's cache, against the check
# inferring that instance apart. Each edit redefines the method (the definition hook checks it), then calls it
# on a member (the forwarder boxes; the box's instance runs). Per edit: the definition's time, the first call's
# time, the compile time of each (`Base.cumulative_compile_time_ns`), and whether the call's instance at the box
# is the CodeInstance the check made.
#     julia --project=<TraitWorld-unified> edit.jl cache|apart [edits]
using TraitWorld
const MODE = get(ARGS, 1, "cache")
const N = parse(Int, get(ARGS, 2, "5"))
if MODE == "apart"
    # the check infers the instance apart (W-151's reading): the cache is not asked
    @eval TraitWorld _box_instance(@nospecialize(sig), world::UInt) = nothing
end

module Bounded
using TraitWorld
@trait_module first_seen = false
@trait ColTable begin
    @default_dynamic
    ncols(t::ColTable)::Int
    col(t::ColTable, i::Int)::Vector{Float64}
end
struct Cols; data::Vector{Vector{Float64}}; end
@implement ColTable Cols begin
    ncols(t) = length(t.data)
    col(t, i) = t.data[i]
end
end
using .Bounded: Cols, ColTable

const T = Cols([rand(100) for _ in 1:4])
ct() = Base.cumulative_compile_time_ns()[1]
# the valid CodeInstances of the method's instance at the box (the check's, where it read Julia's cache)
function cis_at_box(f)
    mi = Base.method_instance(Tuple{typeof(f), Dynamic{ColTable}})
    (mi isa Core.MethodInstance && isdefined(mi, :cache)) || return 0
    n = 0; ci = mi.cache
    while true
        ci.max_world == typemax(UInt) && ci.owner === nothing && (n += 1)
        isdefined(ci, :next) || break
        ci = ci.next
    end
    return n
end
# the instances of `f`'s methods inferred into Julia's cache, by signature (the method at the kept forms at the box;
# the forwarder at its own signature)
inferred_of(f, cis) = [string(Base.unwrap_unionall(ci.def.specTypes).parameters[2]) for ci in cis
                       if ci.def.def isa Method && ci.def.def.name === nameof(f)]
# the lists Julia's inference appends what it caches to (rooted here: the runtime holds a plain pointer)
const INF1 = Core.CodeInstance[]
const INF2 = Core.CodeInstance[]
function edit(k)
    ex = :(summarize(t::ColTable) = (s = 0.0; for i in 1:ncols(t); s += sum(col(t, i)); end; s / ncols(t) + $k))
    inf1 = empty!(INF1)
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), inf1)
    c0 = ct(); t0 = time_ns()
    Core.eval(Bounded, ex)
    t1 = time_ns(); c1 = ct()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    f = getglobal(Bounded, :summarize)
    before = cis_at_box(f)
    inf2 = empty!(INF2)
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), inf2)
    t1b = time_ns(); c1b = ct()
    r = Base.invokelatest(f, T)
    t2 = time_ns(); c2 = ct()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    return (def = (t1 - t0) / 1e6, defc = (c1 - c0) / 1e6, call = (t2 - t1b) / 1e6, callc = (c2 - c1b) / 1e6, r = r,
            cis = before, cis_after = cis_at_box(f), inf_def = inferred_of(f, inf1), inf_call = inferred_of(f, inf2))
end
Base.cumulative_compile_timing(true)
println("# E-440 edit ", MODE, " ", N, " edits | ", Base.GIT_VERSION_INFO.commit_short, " | load ", read("/proc/loadavg", String)[1:14])
rows = [edit(k) for k in 0:N]
for (k, x) in enumerate(rows)
    println(k == 1 ? "first " : "edit  ", rpad(round(x.def, digits = 1), 7), " ms define (", rpad(round(x.defc, digits = 1), 7),
            " compiling) | ", rpad(round(x.call, digits = 2), 7), " ms first call (", rpad(round(x.callc, digits = 2), 6),
            " compiling) | valid code at the box: after the definition ", x.cis, ", after the call ", x.cis_after,
            " | inferred at the definition: ", x.inf_def, "; at the call: ", x.inf_call)
end
med(v) = sort(v)[(length(v) + 1) ÷ 2]
ed = rows[2:end]
println("median of the edits: define ", round(med([x.def for x in ed]), digits = 1), " ms; first call ",
        round(med([x.call for x in ed]), digits = 2), " ms; together ", round(med([x.def + x.call for x in ed]), digits = 1), " ms")
