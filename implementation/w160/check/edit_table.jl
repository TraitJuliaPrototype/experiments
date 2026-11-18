# E-440 (W-160 (c)): E-388's edit (TraitTables' `summarize`, redefined in a session) with the library alone, on
# `julia-next`: the trait `Column{T}`, `numsummary`, `othersummary` and `summarize` as TraitTables' TableCore writes
# them, in a module that declares `bounded`, the trait with the default `Dynamic` so that a column is boxed, and
# `summarize` written `c::Column{E}` (a trait written with its parameters left open is not erased, traits §7.8,
# open issue 204). Per
# edit: the definition's time (the check), then a box's first call (`summarize(Dynamic{Column{Float64}}(v), …)`),
# and the instances of `summarize` inferred into Julia's cache at each. `cache`: the check reads the instance at
# the box from Julia's cache; `apart`: the check infers it apart (W-151's reading).
#     julia --project=<TraitWorld> edit_table.jl cache|apart [edits]
using TraitWorld
const MODE = get(ARGS, 1, "cache")
const N = parse(Int, get(ARGS, 2, "5"))
MODE == "apart" && @eval TraitWorld _box_instance(@nospecialize(sig), world::UInt) = nothing

module TC
using TraitWorld
@trait_module
@trait Column{T} begin
    @default_dynamic
    T = eltype(Self)
    nrows(c::Column)::Int
    cell(c::Column{T}, i::Int)::T
end
@implement Column{T} Vector{T} where {T} begin
    nrows(c) = length(c)
    cell(c, i) = c[i]
end
struct ColSummary
    name::String
    eltype::String
    n::Int
    numeric::Bool
    mean::Float64
    std::Float64
    min::Float64
    max::Float64
    sum::Float64
    ndistinct::Int
    nmissing::Int
end
function numsummary(c::Column, name::String, n::Int, nmiss::Int, T::String)
    s = 0.0
    lo, hi = Inf, -Inf
    for i in 1:n
        x = cell(c, i)
        x === missing && continue
        v = Float64(x)
        s += v
        lo = min(lo, v)
        hi = max(hi, v)
    end
    k = n - nmiss
    m = s / k
    q = 0.0
    for i in 1:n
        x = cell(c, i)
        x === missing && continue
        q += (Float64(x) - m)^2
    end
    return ColSummary(name, T, n, true, m, k > 1 ? sqrt(q / (k - 1)) : NaN, lo, hi, s, 0, nmiss)
end
function othersummary(c::Column{E}, name::String, n::Int, nmiss::Int, T::String) where {E}
    seen = Set{E}()
    for i in 1:n
        x = cell(c, i)
        x === missing || push!(seen, x)
    end
    return ColSummary(name, T, n, false, NaN, NaN, NaN, NaN, NaN, length(seen), nmiss)
end
end

const SUMMARIZE = quote
    function summarize(c::Column{E}, name::String) where {E}
        n = nrows(c)
        n == 0 && return ColSummary(name, "", 0, false, NaN, NaN, NaN, NaN, NaN, 0, 0)
        nmiss = 0
        first = 0
        for i in 1:n
            if cell(c, i) === missing
                nmiss += 1
            elseif first == 0
                first = i
            end
        end
        first == 0 && return ColSummary(name, "Missing", n, false, NaN, NaN, NaN, NaN, NaN, 0, nmiss)
        x = cell(c, first)
        T = nmiss > 0 ? "Union{Missing, " * string(typeof(x)) * "}" : string(typeof(x))
        return x isa Real ? numsummary(c, name, n, nmiss, T) : othersummary(c, name, n, nmiss, T)
    end
end
const COL = Dynamic{TC.Column{Float64}}(rand(1000))
inferred_of(cis) = [string(Base.unwrap_unionall(ci.def.specTypes).parameters[2]) for ci in cis
                    if ci.def.def isa Method && ci.def.def.name === :summarize]
# the lists Julia's inference appends what it caches to (rooted here: the runtime holds a plain pointer)
const INF1 = Core.CodeInstance[]
const INF2 = Core.CodeInstance[]
function edit()
    inf1 = empty!(INF1)
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), inf1)
    t0 = time_ns()
    Core.eval(TC, SUMMARIZE)
    t1 = time_ns()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    inf2 = empty!(INF2)
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), inf2)
    t2 = time_ns()
    r = Base.invokelatest(getglobal(TC, :summarize), COL, "x")
    t3 = time_ns()
    ccall(:jl_set_newly_inferred, Cvoid, (Any,), nothing)
    return (def = (t1 - t0) / 1e6, call = (t3 - t2) / 1e6, at_def = inferred_of(inf1), at_call = inferred_of(inf2))
end
println("# E-440 table edit ", MODE, " ", N, " edits | load ", read("/proc/loadavg", String)[1:14])
rows = [edit() for _ in 0:N]
for (k, x) in enumerate(rows)
    println(k == 1 ? "first " : "edit  ", rpad(round(x.def, digits = 1), 7), " ms define | ", rpad(round(x.call, digits = 1), 7),
            " ms a box's first call | summarize's instances inferred: at the definition ", x.at_def, ", at the call ", x.at_call)
end
med(v) = sort(v)[(length(v) + 1) ÷ 2]
ed = rows[2:end]
println("median of the edits: define ", round(med([x.def for x in ed]), digits = 1), " ms; a box's first call ",
        round(med([x.call for x in ed]), digits = 1), " ms; together ", round(med([x.def + x.call for x in ed]), digits = 1), " ms")
