# Open issue 251: every method at a trait that a corpus defines, read at the box under each reading of
# `readings.jl`; the verdicts that differ from the reading in force (R0), each with its statements.
#     H_CORPUS=library  $JN --project=$LIBG       corpus.jl     the library's tests (test/runtests.jl)
#     H_CORPUS=intro|tutorial|strict  (the same)                 a documentation example (experiments/docs-examples)
#     H_CORPUS=demos    $JN --project=$ENVG       corpus.jl     the demonstrators (d-probes/demo_check.jl's modules)
# H_OUT=<file>: the records, one line per method and reading (TSV). Methods are taken twice:
# - at each check the library makes while the corpus runs (a method in a `bounded` scope, at its definition, in the
#   world of that moment; a method the check refuses is deleted after, so only this reading sees it): the library's
#   `check_at_box` is replaced by its own body (`Readings.r0`) and a record of every reading;
# - at the end, every method of the session's method table that is read at the box, in the corpus's modules.
const H_CORPUS_ = get(ENV, "H_CORPUS", "library")
const H_OUT_ = get(ENV, "H_OUT", "/dev/stdout")
using TraitWorld
const H_TW = TraitWorld
println("TraitWorld at ", pathof(TraitWorld), "  commit ", readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) log -1 --format=%h`),
        isempty(readchomp(`git -C $(dirname(dirname(pathof(TraitWorld)))) status --short src`)) ? "" : "+dirty",
        "  corpus ", H_CORPUS_, "  load ", join(split(read("/proc/loadavg", String))[1:3], " "))
include(joinpath(@__DIR__, "readings.jl"))
using .Readings: READINGS, all_readings, verdict, Fault

const H_RECORDS = Dict{Method, Tuple{String, Vector{Pair{Symbol,Any}}}}()   # method => (where taken, readings)
const H_T0 = time()
function h_record!(m::Method, how::String, world::UInt)
    rs = try all_readings(m; world) catch e; [(:R0 => string("ERROR ", sprint(showerror, e)))] end
    H_RECORDS[m] = (how, rs)
    return rs
end

if H_CORPUS_ != "demos"
    # the library's check, recorded: its own body, then every reading in the same world
    @eval TraitWorld function check_at_box(m::Method; world::UInt = Base.get_world_counter())
        r = Main.Readings.r0(m; world)
        try
            Base.invokelatest(Main.h_record!, m, "at its definition", world)
        catch
        end
        return r
    end
end

const H_LIBDIR = dirname(dirname(pathof(TraitWorld)))
const H_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
h_demo_mods = Module[]
if H_CORPUS_ == "library"
    cd(H_LIBDIR) do
        include(joinpath(H_LIBDIR, "test", "runtests.jl"))
    end
elseif H_CORPUS_ in ("intro", "tutorial", "strict")
    # a script that fails a check exits: the h_survey runs at exit too
    atexit(() -> Base.invokelatest(Main.h_survey))
    include(joinpath(H_ROOT, "experiments", "docs-examples", H_CORPUS_ * ".jl"))
elseif H_CORPUS_ == "demos"
    @eval using TraitTables, TraitDifferentialEquations, TraitMakie
    for m in Base.loaded_modules_array()
        f = pathof(m)
        f === nothing && continue
        any(d -> occursin("/$d/", f), ("TraitTables", "TraitDifferentialEquations", "TraitMakie")) && push!(h_demo_mods, m)
    end
    function submodules!(acc, M)
        for n in names(M; all = true)
            isdefined(M, n) || continue
            v = getglobal(M, n)
            v isa Module && v !== M && parentmodule(v) === M && !(v in acc) && (push!(acc, v); submodules!(acc, v))
        end
        return acc
    end
    for M in copy(h_demo_mods)
        submodules!(h_demo_mods, M)
    end
end

# whether a method belongs to the corpus
function h_in_corpus(m::Method)
    M = m.module
    H_CORPUS_ == "demos" && return M in h_demo_mods
    root = Base.moduleroot(M)
    (root === Base || root === Core || root === TraitWorld || root === Main.Readings) && return false
    pkgdir(root) === nothing || return false          # a package or a standard library
    return true
end
h_live(m::Method) = any(mm -> (mm::Core.MethodMatch).method === m, something(Base._methods_by_ftype(m.sig, -1, Base.get_world_counter()), Any[]))

const H_DONE = Ref(false)
function h_survey()
    H_DONE[] && return
    H_DONE[] = true
    # the methods of the session's table that are read at the box, not yet recorded
    cands = Method[]
    Base.visit(Core.methodtable) do m
        m isa Method || return
        haskey(H_RECORDS, m) && return
        h_in_corpus(m) || return
        H_TW._at_box_checked(m) || return
        push!(cands, m)
    end
    nlive = 0
    for m in cands
        h_live(m) || (println("   not live (deleted or replaced): ", m); continue)
        nlive += 1
        h_record!(m, "at the end", Base.get_world_counter())
    end
    println("   candidates in the method table: ", length(cands), ", live: ", nlive)
    io = H_OUT_ == "/dev/stdout" ? stdout : open(H_OUT_, "w")
    println(io, "method\tfile:line\tmodule\ttaken\tbounded scope\t@unbounded\treading\tverdict\tfaults")
    ndiff = Dict{Symbol,Int}(k => 0 for (k, _) in READINGS)
    diffs = Dict{Symbol,Vector{String}}(k => String[] for (k, _) in READINGS)
    nread = 0
    nerr = 0
    for (m, (how, rs)) in sort!(collect(H_RECORDS); by = p -> (string(p[1].module), string(p[1].file), p[1].line))
        w = try H_TW._written_method(m) catch; string(m) end
        sc = try H_TW._bounded(m) catch; missing end
        ub = try H_TW._bounded_option(m) === false catch; missing end
        r0 = first(rs)[2]
        r0 === nothing && continue
        nread += 1
        v0 = verdict(r0)
        for (k, r) in rs
            fs = r isa Vector ? join(string.(r), " | ") : string(r)
            println(io, w, "\t", basename(string(m.file)), ":", m.line, "\t", m.module, "\t", how, "\t", sc, "\t", ub, "\t", k, "\t", verdict(r), "\t", fs)
            r isa String && (nerr += 1)
            if verdict(r) != v0
                ndiff[k] += 1
                push!(diffs[k], string(w, "  [", basename(string(m.file)), ":", m.line, "; ", how, sc === true ? "; bounded scope" : "", ub === true ? "; @unbounded" : "", "]\n        ",
                                       v0, " -> ", verdict(r), ": ", r isa Vector ? join(string.(r), " | ") : string(r)))
            end
        end
    end
    io === stdout || close(io)
    println("\n== corpus ", H_CORPUS_, ": ", nread, " methods read at the box (", count(v -> v[1] == "at its definition", values(H_RECORDS)),
            " taken at a check while the corpus ran); ", nerr, " readings raised; ", round(time() - H_T0; digits = 1), " s")
    println("   R0 not bounded: ", count(v -> verdict(first(v[2])[2]) == "not bounded", values(H_RECORDS)))
    permod = Dict{String,Int}()
    for m in keys(H_RECORDS); permod[string(m.module)] = get(permod, string(m.module), 0) + 1; end
    println("   per module: ", join(sort!([string(k, " ", v) for (k, v) in permod]), ", "))
    for (k, _) in READINGS
        k === :R0 && continue
        println("\n-- reading ", k, ": ", ndiff[k], " verdicts differ from R0")
        foreach(d -> println("   ", d), diffs[k])
    end
end
H_CORPUS_ in ("intro", "tutorial", "strict") || h_survey()
