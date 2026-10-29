# E-256 (U4): is an untyped function a `Dynamic` over `Any`?
# `f(@nospecialize x)` against the same body at a `Dynamic{Sh}` bound of a one-operation trait.
# For each form: the CodeInstances made per argument type, `code_typed` (each call on `x` a run-time
# site? its result type), and the time per call in a loop over 1000 values cycling four types.
#
#     ../../tools/jl --name w83u4 ../../../julia-1.13/julia --startup-file=no --project=. u4.jl            # product
#     ../../tools/jl --name w83u4 ../../../julia-1.13/julia -J ../../../julia-1.13/usr/lib/julia/facts/sys.so --startup-file=no --project=. u4.jl   # all
#     U4_TIME=0 skips the timings.
using BenchmarkTools, Printf
using TraitWorld
const CC = Base.Compiler
const SETTING = CC.NativeInterpreter().facts ? "all" : "product"
const TWDIR = pkgdir(TraitWorld)
loadavg() = join(first(split(read("/proc/loadavg", String)), 3), " ")
println("== U4  julia ", VERSION, " (", Base.GIT_VERSION_INFO.commit_short, ")  setting ", SETTING,
        "  TraitWorld ", readchomp(`git -C $TWDIR rev-parse --short HEAD`), "  load ", loadavg())

# --- the types, the plain twins, the trait --------------------------------------------------------
# twelve types: P1–P4 for the top-level calls and the timings, P5–P8 for the typed callers,
# P9–P12 for the callers that do not know the type, so that each census sees types not seen before
struct P1; a::Float64; end
struct P2; a::Float64; end
struct P3; a::Float64; end
struct P4; a::Float64; end
struct P5; a::Float64; end
struct P6; a::Float64; end
struct P7; a::Float64; end
struct P8; a::Float64; end
struct P9; a::Float64; end
struct P10; a::Float64; end
struct P11; a::Float64; end
struct P12; a::Float64; end
parea(s::P1) = 1.0 * s.a
parea(s::P2) = 2.0 * s.a
parea(s::P3) = 3.0 * s.a
parea(s::P4) = 4.0 * s.a
parea(s::P5) = 5.0 * s.a
parea(s::P6) = 6.0 * s.a
parea(s::P7) = 7.0 * s.a
parea(s::P8) = 8.0 * s.a
parea(s::P9) = 9.0 * s.a
parea(s::P10) = 10.0 * s.a
parea(s::P11) = 11.0 * s.a
parea(s::P12) = 12.0 * s.a
qarea(s::P1) = 1.0 * s.a; qarea(s::P2) = 2.0 * s.a        # 2 methods: within plain inference's max_methods

# the untyped form in Main (plain code in the product setting, facts code under `all`)
fu4(@nospecialize x) = parea(x) + 1.0
fu2(@nospecialize x) = qarea(x) + 1.0

@trait_module module UCore
using TraitWorld
using ..Main: P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, parea, qarea
export Sh, area, gd, gb, tu4, tu2, tua, tcg, tloopd, tloopi, tloopu
@trait Sh begin
    area(s::Sh)::Float64
end
@implement Sh P1 begin area(s) = 1.0 * s.a end
@implement Sh P2 begin area(s) = 2.0 * s.a end
@implement Sh P3 begin area(s) = 3.0 * s.a end
@implement Sh P4 begin area(s) = 4.0 * s.a end
@implement Sh P5 begin area(s) = 5.0 * s.a end
@implement Sh P6 begin area(s) = 6.0 * s.a end
@implement Sh P7 begin area(s) = 7.0 * s.a end
@implement Sh P8 begin area(s) = 8.0 * s.a end
@implement Sh P9 begin area(s) = 9.0 * s.a end
@implement Sh P10 begin area(s) = 10.0 * s.a end
@implement Sh P11 begin area(s) = 11.0 * s.a end
@implement Sh P12 begin area(s) = 12.0 * s.a end
# the bounded forms: the same body at a `Dynamic{Sh}` position (an annotation), and at a plain bound
# called with values that carry `Dynamic`
gd(x::Dynamic{Sh}) = area(x) + 1.0
gb(x::Sh) = area(x) + 1.0
tcg(x::Dynamic{Sh}) = gd(x) + 0.0     # a bounded caller of gd: trait code calling trait code
# the loops written in trait code (compiled by facts in both settings)
tloopd(v::Vector{Dynamic{Sh}}) = (s = 0.0; for x in v; s += gd(x); end; s)     # an unbounded function, items typed
tloopi(xs::Iterable{Sh}) = (s = 0.0; for x in xs; s += gd(x); end; s)           # a bound with dynamic items
tloopu(v::Vector{Any}) = (s = 0.0; for x in v; s += tu4(x); end; s)
# the untyped form inside a trait module: compiled by facts in both settings
tu4(@nospecialize x) = parea(x) + 1.0
tu2(@nospecialize x) = qarea(x) + 1.0
tua(@nospecialize x) = area(x) + 1.0          # the trait's operation on an untyped value
end
using .UCore

const PS = (P1(1.0), P2(1.0), P3(1.0), P4(1.0))
const PSB = (P5(1.0), P6(1.0), P7(1.0), P8(1.0))
const PSC = (P9(1.0), P10(1.0), P11(1.0), P12(1.0))
const DS = map(p -> Dynamic{Sh}(p), PS)
const WS = map(p -> with_dynamic(p), PS)

# --- CodeInstances: every method's specializations, before and after a call -----------------------
function ci_census()
    d = IdDict{Any,Vector{Any}}()
    Base.visit(Core.methodtable) do m
        for mi in Base.specializations(m)
            cis = Any[]
            ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing
                push!(cis, ci)
                ci = isdefined(ci, :next) ? ci.next : nothing
            end
            d[mi] = cis
        end
    end
    return d
end
ownername(o) = o === nothing ? "plain" : o === CC.FACTS_OWNER ? "facts" : string(o)
function newcis(before, after)
    out = Tuple{Any,String}[]
    for (mi, cis) in after
        old = get(before, mi, Any[])
        for ci in cis
            any(c -> c === ci, old) || push!(out, (mi.specTypes, ownername(ci.owner)))
        end
    end
    return out
end
ci_census(); ci_census()          # compile the census itself first

println("\n-- CodeInstances made by each call (top-level call, after the previous ones)")
function census_calls(label, f, args)
    for a in args
        b = ci_census()
        Base.invokelatest(f, a)
        n = newcis(b, ci_census())
        own = filter(t -> occursin(string(nameof(f)), string(t[1])), n)
        println(@sprintf("%-4s %-28s arg %-24s new CIs: %3d  (of the function itself: %d)", SETTING, label,
                         string(typeof(a)), length(n), length(own)))
        for (T, o) in n
            println("        ", o, "  ", T)
        end
    end
end
census_calls("fu4(@nospecialize) Main", fu4, PS)
census_calls("fu2(@nospecialize) Main", fu2, PS[1:2])
census_calls("tu4(@nospecialize) UCore", tu4, PS)
census_calls("tua(@nospecialize) UCore", tua, PS)
census_calls("gd(x::Dynamic{Sh})", gd, DS)
census_calls("gb(x::Sh), Dynamic values", gb, WS)
census_calls("gb(x::Sh), Compiled (plain)", gb, PS)
# from compiled callers: the argument's type known to the caller (as in a loop over a typed container)
cu4(x) = fu4(x)                       # specialized per x's type; fu4's own MI stays at Any
cg(x::Dynamic{Sh}) = gd(x)
ctu(x) = tu4(x)
println("\n-- from compiled callers (the caller compiled per argument type; counted: everything new)")
census_calls("cu4(x) = fu4(x)", cu4, PSB)
census_calls("ctu(x) = tu4(x)", ctu, PSB)
census_calls("cg(x::Dynamic{Sh}) = gd(x)", cg, map(p -> Dynamic{Sh}(p), PSB))
const ANYP = Any[PSC...]; const ANYD = Any[map(p -> Dynamic{Sh}(p), PSC)...]
cua(v::Vector{Any}, i) = fu4(v[i])    # the caller does not know the type
cga(v::Vector{Any}, i) = gd(v[i])
println("\n-- from compiled callers that do not know the argument's type (v::Vector{Any})")
for i in 1:4
    b = ci_census(); cua(ANYP, i); n = newcis(b, ci_census())
    println(@sprintf("%-4s cua(v, %d) = fu4(v[i]) arg %-4s new CIs: %3d", SETTING, i, string(typeof(ANYP[i])), length(n)))
    foreach(t -> println("        ", t[2], "  ", t[1]), n)
end
for i in 1:4
    b = ci_census(); cga(ANYD, i); n = newcis(b, ci_census())
    println(@sprintf("%-4s cga(v, %d) = gd(v[i]) held %-4s new CIs: %3d", SETTING, i, string(typeof(getfield(ANYD[i], :t))), length(n)))
    foreach(t -> println("        ", t[2], "  ", t[1]), n)
end

# MethodInstances of each function, after all calls
println("\n-- MethodInstances of each function after the calls")
for f in (fu4, fu2, tu4, tu2, tua, gd, gb, cu4, cg, ctu)
    for m in methods(f)
        for mi in Base.specializations(m)
            cis = Any[]; ci = isdefined(mi, :cache) ? mi.cache : nothing
            while ci !== nothing; push!(cis, ownername(ci.owner)); ci = isdefined(ci, :next) ? ci.next : nothing; end
            println("  ", mi.specTypes, "  CIs: ", join(cis, ", "))
        end
    end
end

# --- code_typed -------------------------------------------------------------------------------------
const FACTS = CC.NativeInterpreter(; owner = CC.FACTS_OWNER)
const PLAIN = CC.NativeInterpreter(; owner = nothing)
function show_typed(label, f, T, interp)
    res = (f === nothing ? Base.code_typed_by_type(T; interp, optimize = true) : code_typed(f, T; interp, optimize = true))
    length(res) == 1 || (println("\n---- ", label, " at ", T, ": ", length(res), " results, skipped"); return)
    src, rt = only(res)
    println("\n---- ", label, "  at ", T, "  (", interp === FACTS ? "facts" : "plain", " compiler), result ", rt)
    for (i, st) in enumerate(src.code)
        st isa Expr && st.head in (:call, :invoke, :foreigncall) || continue
        s = sprint(show, st)
        occursin(r"area|parea|qarea|split|_dynop|jl_apply|Core\.|invoke", s) || continue
        println(@sprintf("   %3d  %-6s ::%-10s %s", i, st.head, string(src.ssavaluetypes[i]), first(s, 150)))
    end
end
mainint = SETTING == "all" ? FACTS : PLAIN
println("\n-- code_typed (each function under the compiler that compiles it in this setting)")
show_typed("fu4 Main", fu4, (Any,), mainint)
show_typed("fu2 Main", fu2, (Any,), mainint)
show_typed("tu4 UCore", tu4, (Any,), FACTS)
show_typed("tu2 UCore", tu2, (Any,), FACTS)
show_typed("tua UCore", tua, (Any,), FACTS)
# the bounded forms: the worker that runs for a `Dynamic{Sh}` (the entry's specialization, as the census shows)
tcg(DS[1])
for g in (gd, gb, tcg), m in methods(g), mi in Base.specializations(m)
    ci = isdefined(mi, :cache) ? mi.cache : nothing
    ci === nothing && continue
    show_typed("$(nameof(g)): the compiled specialization", nothing, mi.specTypes, ci.owner === nothing ? PLAIN : FACTS)
end
show_typed("tloopd, trait code calling gd", tloopd, (Vector{Dynamic{Sh}},), FACTS)
show_typed("cg, a typed caller of gd", cg, (Dynamic{Sh},), mainint)
show_typed("cu4, a typed caller of fu4", cu4, (P1,), mainint)

# --- time per call ------------------------------------------------------------------------------------
const N = 1000
loop(f::F, v) where {F} = (s = 0.0; for x in v; s += f(x); end; s)
macro row(label, ex)
    quote
        local tr = @benchmark $ex samples = 2000 seconds = 2
        println(@sprintf("%-8s %-58s %8.2f ns/call %6.1f B/call  (median of %d samples)", SETTING, $label,
                         median(tr).time / N, median(tr).memory / N, length(tr.times)))
    end |> esc
end
if get(ENV, "U4_TIME", "1") != "0"
    vany = Any[PS[mod1(i, 4)] for i in 1:N]
    vany2 = Any[PS[mod1(i, 2)] for i in 1:N]
    vdyn = Dynamic{Sh}[DS[mod1(i, 4)] for i in 1:N]
    vdyn2 = Dynamic{Sh}[DS[mod1(i, 2)] for i in 1:N]
    @assert loop(fu4, vany) == loop(gd, vdyn) == loop(tu4, vany) == loop(tua, vany) == loop(gb, vdyn)
    println("\n-- time per call, 1000 values cycling 4 types (2 where named); medians; load ", loadavg())
    @row "fu4(@nospecialize) Main, Vector{Any}, 4 types" loop($fu4, $vany)
    @row "tu4(@nospecialize) UCore, Vector{Any}, 4 types" loop($tu4, $vany)
    @row "tua(@nospecialize) UCore (area), Vector{Any}, 4 types" loop($tua, $vany)
    @row "gd(x::Dynamic{Sh}), Vector{Dynamic{Sh}}, 4 types" loop($gd, $vdyn)
    @row "gb(x::Sh), Vector{Dynamic{Sh}}, 4 types" loop($gb, $vdyn)
    @row "fu2(@nospecialize) Main, Vector{Any}, 2 types" loop($fu2, $vany2)
    @row "tu2(@nospecialize) UCore, Vector{Any}, 2 types" loop($tu2, $vany2)
    @row "gd(x::Dynamic{Sh}), Vector{Dynamic{Sh}}, 2 types" loop($gd, $vdyn2)
    @row "trait code: tloopd, gd(x) over Vector{Dynamic{Sh}}, 4 types" tloopd($vdyn)
    @row "trait code: tloopi(xs::Iterable{Sh}), gd(x), 4 types" tloopi($vdyn)
    @row "trait code: tloopu, tu4(x) over Vector{Any}, 4 types" tloopu($vany)
    # the operation alone, no function around it: a run-time site on Any, and the split on a Dynamic
    @row "parea(x) alone, Vector{Any}, 4 types" loop($parea, $vany)
    @row "area(x) alone on Dynamic{Sh}, Vector{Dynamic{Sh}}, 4 types" loop($area, $vdyn)
    # the call itself where the loop is not in the way: one value, the caller does not know its type
    r = Ref{Any}(PS[3]); rd = Ref{Any}(DS[3])
    @row "fu4(r[]) one call, r::Ref{Any}  (x1000)" (for _ in 1:N; fu4($r[]); end)
    @row "gd(rd[]) one call, rd::Ref{Any} (x1000)" (for _ in 1:N; gd($rd[]); end)
end
println("\n== done  load ", loadavg())
