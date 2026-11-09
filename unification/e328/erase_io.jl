# E-328: what erasing the stream costs code that writes to it a little at a time
# (open issue 164, proposal (d): `IO` a trait compiled once by default).
#
# The same workloads write into an IOBuffer three ways:
#   raw     the IOBuffer itself
#   known   IOContext{IOBuffer}: the stream's type known, as code compiled per type sees it
#   erased  IOContext{IO}: every call on the stream dispatches when it runs, as in a method compiled
#           once, without the split over the trait's first members (so the pessimistic case)
#   dyn     DynIO: erased, each call on the stream dispatches when it runs, its result asserted at the
#           operation's declared type (`unsafe_write` and `write(io, ::UInt8)` `::Int`), as a run-time
#           site of the design does (compiler §7)
#   split   SplitIO: as dyn, but the operations branch over four candidate types (IOBuffer, IOStream, TTY,
#           PipeEndpoint) with direct calls, a dynamic call past them, as compiler §7's split over a
#           trait's first members would
# Base keeps an IOContext{IO} erased when code wraps it again (`IOContext(io::IOContext, dict)` keeps
# `typeof(io)`), so `show`'s own `IOContext(io, :compact => true)` stays erased.
#
# Run: julia --startup-file=no erase_io.jl [pkgs]
#   pkgs: also upstream CSV's `write` and DataFrames' display; needs --project=forks-unified/env_upstream
#   and DATA pointing at forks-unified/data.
using Printf

const WITH_PKGS = "pkgs" in ARGS
WITH_PKGS && @eval using CSV, DataFrames

raw(b) = b
known(b) = IOContext(b)                                       # IOContext{IOBuffer}
erased(b) = IOContext{IO}(b, Base.ImmutableDict{Symbol, Any}())

abstract type ErasedIO <: Base.AbstractPipe end
struct DynIO <: ErasedIO
    io::IO
end
struct SplitIO <: ErasedIO
    io::IO
end
Base.pipe_writer(s::ErasedIO) = s.io
Base.pipe_reader(s::ErasedIO) = s.io
@inline route(f::F, s::DynIO) where {F} = f(s.io)
@inline function route(f::F, s::SplitIO) where {F}
    io = s.io
    if io isa IOBuffer
        f(io)
    elseif io isa IOStream
        f(io)
    elseif io isa Base.TTY
        f(io)
    elseif io isa Base.PipeEndpoint
        f(io)
    else
        f(io)                                                 # past the candidates: a dynamic call
    end
end
Base.write(s::ErasedIO, b::UInt8) = route(x -> write(x, b), s)::Int
Base.unsafe_write(s::ErasedIO, p::Ptr{UInt8}, n::UInt) = route(x -> unsafe_write(x, p, n), s)::Int
Base.lock(s::ErasedIO) = (route(lock, s); nothing)
Base.unlock(s::ErasedIO) = (route(unlock, s); nothing)
dyn(b) = DynIO(b)
split(b) = SplitIO(b)

const WAYS = (("raw", raw), ("known", known), ("erased", erased), ("dyn", dyn), ("split", split))

const N5 = 100_000
const FLOATS = [i / 7 for i in 1:N5]
const STRS = [string("s", i) for i in 1:10_000]
const VEC = [i / 7 for i in 1:10_000]

# Workloads on a stream (each takes the stream)
w_print_int(io) = for i in 1:N5; print(io, i); end
w_print_float(io) = for x in FLOATS; print(io, x); end
w_print_str(io) = for i in 1:N5; print(io, "ab"); end
w_write_char(io) = for i in 1:1_000_000; write(io, 'a'); end
w_write_byte(io) = for i in 1:1_000_000; write(io, 0x61); end
w_join(io) = join(io, STRS, ", ")
w_printf(io) = for i in 1:10_000; @printf(io, "%d %.3f\n", i, i / 7); end
w_show_vec(io) = show(IOContext(io, :limit => false), MIME"text/plain"(), VEC)

# Strings built as `string(...)` builds them: a new buffer per string (takes the way)
function build(way, i, x)
    b = IOBuffer(sizehint = 24)
    io = way(b)
    print(io, "a="); print(io, i); print(io, ", b="); print(io, x)
    return String(take!(b))
end
w_strings(way) = (n = 0; for i in 1:N5; n += sizeof(build(way, i, FLOATS[i])); end; n)

const WORKLOADS = Any[
    ("print Int x1e5", w_print_int, :stream),
    ("print Float64 x1e5", w_print_float, :stream),
    ("print \"ab\" x1e5", w_print_str, :stream),
    ("write Char x1e6", w_write_char, :stream),
    ("write UInt8 x1e6", w_write_byte, :stream),
    ("join 1e4 strings", w_join, :stream),
    ("@printf x1e4", w_printf, :stream),
    ("show Vector 1e4", w_show_vec, :stream),
    ("string(...) x1e5", w_strings, :way),
]

if WITH_PKGS
    @eval begin
        const DF = CSV.read(joinpath(get(ENV, "DATA", "data"), "people.csv"), DataFrame)
        const BIG = DataFrame(a = 1:10^4, b = (1:10^4) ./ 7, c = string.(1:10^4))
        w_csv(io) = CSV.write(io, BIG)
        w_show_df(io) = show(IOContext(io, :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), DF)
        w_show_big(io) = show(IOContext(io, :limit => true, :displaysize => (40, 120)), MIME"text/plain"(), BIG)
    end
    push!(WORKLOADS, ("CSV.write 1e4 rows", w_csv, :stream))
    push!(WORKLOADS, ("show people.csv frame", w_show_df, :stream))
    push!(WORKLOADS, ("show 1e4-row frame", w_show_big, :stream))
end

function once(f, kind, way)
    GC.gc(false)
    if kind === :stream
        b = IOBuffer()
        io = way(b)
        t = time_ns(); Base.invokelatest(f, io); dt = (time_ns() - t) / 1e6
        return dt, position(b)
    else
        t = time_ns(); n = Base.invokelatest(f, way); dt = (time_ns() - t) / 1e6
        return dt, n
    end
end

med(v) = (s = sort(v); n = length(s); isodd(n) ? s[(n + 1) ÷ 2] : (s[n ÷ 2] + s[n ÷ 2 + 1]) / 2)

const RUNS = parse(Int, get(ENV, "RUNS", "7"))
println("E-328 julia ", VERSION, " ", Base.GIT_VERSION_INFO.commit_short, "; threads ", Threads.nthreads(),
        "; runs ", RUNS, " after a warm-up; load ", strip(read("/proc/loadavg", String)))
times = Dict{Tuple{String, String}, Vector{Float64}}()
bytes = Dict{Tuple{String, String}, Int}()
for (name, f, kind) in WORKLOADS, (wn, way) in WAYS          # warm-up: compiles each way
    _, n = once(f, kind, way)
    bytes[(name, wn)] = n
    times[(name, wn)] = Float64[]
end
for r in 1:RUNS, (name, f, kind) in WORKLOADS, (wn, way) in WAYS   # interleaved
    dt, _ = once(f, kind, way)
    push!(times[(name, wn)], dt)
end
@printf("%-22s %15s %15s %15s %15s %15s  %s\n", "workload (ms: min med)", "raw", "known", "erased",
        "dyn", "split", "against known, by min: erased dyn split; bytes")
for (name, _, _) in WORKLOADS
    s = [(minimum(times[(name, wn)]), med(times[(name, wn)])) for (wn, _) in WAYS]
    same = allequal(bytes[(name, wn)] for (wn, _) in WAYS)
    @printf("%-22s %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f   %5.2f %5.2f %5.2f  %9d%s\n", name,
            s[1]..., s[2]..., s[3]..., s[4]..., s[5]..., s[3][1] / s[2][1], s[4][1] / s[2][1], s[5][1] / s[2][1],
            bytes[(name, "known")], same ? "" : "  OUTPUT DIFFERS")
end
println("load at end ", strip(read("/proc/loadavg", String)))
