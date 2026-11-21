# Open issue 251, GT-12: the time of the bounded check per method, under the reading in force and under the proposed
# readings, over the demonstrators' methods read at the box. Each method's instance at the box is inferred again (the
# top frame not cached, its callees cached: what an edit costs, traits §11.2), then read. Two passes; the second is
# reported (the first compiles the readings' own code). One process, one thread.
#     cd $TW_ROOT/TraitDifferentialEquations; $JN --project=$ENVG $W158/h-probes/cost.jl
using TraitWorld, TraitTables, TraitDifferentialEquations, TraitMakie
const TW = TraitWorld
const CC = TW.CC
println("TraitWorld at ", pathof(TraitWorld), "  commit ", readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) log -1 --format=%h`),
        isempty(readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) status --short src`)) ? "" : "+dirty",
        "  load ", join(split(read("/proc/loadavg", String))[1:3], " "), "  threads ", Threads.nthreads())
include(joinpath(@__DIR__, "readings.jl"))
using .Readings: Opts

mods = Module[]
for m in Base.loaded_modules_array()
    f = pathof(m)
    f === nothing && continue
    any(d -> occursin("/$d/", f), ("TraitTables", "TraitDifferentialEquations", "TraitMakie")) && push!(mods, m)
end
function submodules!(acc, M)
    for n in names(M; all = true)
        isdefined(M, n) || continue
        v = getglobal(M, n)
        v isa Module && v !== M && parentmodule(v) === M && !(v in acc) && (push!(acc, v); submodules!(acc, v))
    end
    return acc
end
foreach(M -> submodules!(mods, M), copy(mods))
ms = Method[]
Base.visit(Core.methodtable) do m
    m isa Method && m.module in mods && TW._at_box_checked(m) && Readings.r0(m) !== nothing && push!(ms, m)
end
sort!(ms; by = m -> (string(m.module), string(m.file), m.line))
println(length(ms), " methods read at the box; a walk's result kept across checks (H_MEMO): ", Readings.MEMO[])

const READS = [(:cde, Opts(assert = true, errpath = true, traitbox = true)),
               (:bcde, Opts(follow = true, assert = true, errpath = true, traitbox = true)),
               (:acde, Opts(inferred = true, assert = true, errpath = true, traitbox = true)),
               (:all, Opts(inferred = true, follow = true, assert = true, errpath = true, traitbox = true)),
               (:allf, Opts(inferred = true, follow = true, assert = true, errpath = true, traitbox = true, captured = true))]
fresh() = CC.NativeInterpreter(Base.get_world_counter(); facts = true)
function measure(m::Method)
    w = Base.get_world_counter()
    sig = TW.box_signature(m)
    t_opt = @elapsed (r = Base.code_typed_by_type(sig; interp = fresh(), optimize = true))
    src_opt = r[1][1]
    t_inf = @elapsed (r = Base.code_typed_by_type(sig; interp = fresh(), optimize = false))
    src_inf = r[1][1]
    t_r0 = @elapsed (f0 = TW._box_faults(m, src_opt, fresh(), w))
    out = Dict{Symbol,Any}(:opt => t_opt, :inf => t_inf, :r0 => t_r0, :n0 => length(f0))
    for (k, o) in READS
        out[k] = @elapsed (fs = Readings.faults(m, copy(o.inferred ? src_inf : src_opt), fresh(), o, w))
        out[Symbol(:n, k)] = length(fs)
    end
    return out
end
foreach(measure, ms)                       # the first pass: the readings' own code compiled
GC.gc()
println("walks kept after the first pass: ", length(Readings.MEMOD), "; hits, misses ", Readings.MEMOSTAT)
Readings.MEMOSTAT .= 0
tstat = @elapsed (res = [measure(m) for m in ms])
println("second pass ", round(tstat; digits = 2), " s; walks: hits, misses ", Readings.MEMOSTAT)             # the second pass, reported
ms_(x) = round(1000x; digits = 2)
med(v) = (s = sort(v); s[(length(s) + 1) ÷ 2])
col(k) = [r[k] for r in res]
println("\nper method, ms (median / mean / max), ", length(res), " methods:")
for (k, what) in [(:opt, "inference and optimization of the instance at the box (the kept instance)"),
                  (:inf, "inference before optimization (a second inference)"),
                  (:r0, "the reading in force over the optimized code"),
                  (:cde, "reading (c)+(d)+(e) over the optimized code"),
                  (:bcde, "reading (b)-(e) over the optimized code"),
                  (:acde, "reading (a)+(c)+(d)+(e) over the inferred code"),
                  (:all, "reading (a)-(e) over the inferred code"),
                  (:allf, "reading (a)-(f) over the inferred code")]
    v = col(k)
    println("  ", rpad(k, 5), " ", lpad(ms_(med(v)), 8), " / ", lpad(ms_(sum(v) / length(v)), 8), " / ", lpad(ms_(maximum(v)), 9), "   ", what)
end
c0 = col(:opt) .+ col(:r0)
println("\nthe check per method, ms (median / mean / total):")
for (name, c) in [("in force: inference+optimization, the reading", c0),
                  ("(c)+(d)+(e) over the optimized code", c0 .- col(:r0) .+ col(:cde)),
                  ("(b)-(e) over the optimized code", c0 .- col(:r0) .+ col(:bcde)),
                  ("(a)+(c)+(d)+(e), the inferred code kept from the one inference", c0 .- col(:r0) .+ col(:acde)),
                  ("(a)+(c)+(d)+(e), a second inference", c0 .- col(:r0) .+ col(:inf) .+ col(:acde)),
                  ("(a)-(e), a second inference", c0 .- col(:r0) .+ col(:inf) .+ col(:all)),
                  ("(a)-(f), a second inference", c0 .- col(:r0) .+ col(:inf) .+ col(:allf)),
                  ("(a)-(e), the inferred code kept from the one inference", c0 .- col(:r0) .+ col(:all)),
                  ("(a)-(f), the inferred code kept from the one inference", c0 .- col(:r0) .+ col(:allf))]
    println("  ", rpad(name, 66), lpad(ms_(med(c)), 8), " / ", lpad(ms_(sum(c) / length(c)), 8), " / ", lpad(ms_(sum(c)), 9),
            "   ratio of totals ", round(sum(c) / sum(c0); digits = 3))
end
println("\nthe ten slowest under (a)-(e), ms (inference+opt, second inference, reading in force, reading (a)-(e)):")
for i in sortperm(col(:all); rev = true)[1:min(10, end)]
    r = res[i]
    println("  ", ms_(r[:opt]), "  ", ms_(r[:inf]), "  ", ms_(r[:r0]), "  ", ms_(r[:all]), "   ", TW._written_method(ms[i]))
end
println("\nthe ten slowest under (c)+(d)+(e), ms (inference+opt, reading in force, reading (c)+(d)+(e)):")
for i in sortperm(col(:cde); rev = true)[1:min(10, end)]
    r = res[i]
    println("  ", ms_(r[:opt]), "  ", ms_(r[:r0]), "  ", ms_(r[:cde]), "   ", TW._written_method(ms[i]))
end
println("faults: in force ", sum(col(:n0)), "; (c)+(d)+(e) ", sum(col(:ncde)), "; (b)-(e) ", sum(col(:nbcde)), "; (a)+(c)+(d)+(e) ", sum(col(:nacde)), "; (a)-(e) ", sum(col(:nall)), "; (a)-(f) ", sum(col(:nallf)))
println("load after ", join(split(read("/proc/loadavg", String))[1:3], " "))
