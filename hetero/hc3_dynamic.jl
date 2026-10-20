# E3: Vector{Dynamic{Shape}} with n implementations (HShapes, 64 in the image), product setting.
# Per-element time of `total` against the plain twin `ptotal`, for n = 1, 2, 4, 5, 8, 16, 64;
# then the "which four" question: a vector of only the fifth-registered type against only the first.
using BenchmarkTools
using HShapes, TraitWorld
const SC = HShapes.ShapeCore
const PS = HShapes.PlainShapes
const N = 1000
mode = Base.Compiler.NativeInterpreter().facts ? "all  " : "plain"
println("julia ", VERSION, "  mode ", mode)
cands = Base.Compiler.dynamic_candidates(TraitWorld._family(SC.Shape))
println("registered candidates split over (first four): ", length(cands))
for c in cands; println("   ", first(sprint(show, c), 100)); end
function cyc(n)        # N elements cycling through the first n types
    Dynamic{SC.Shape}[SC.mk(getfield(SC, Symbol(:H, mod1(i, n)))(1.0)) for i in 1:N]
end
pcyc(n) = PS.PShape[getfield(PS, Symbol(:P, mod1(i, n)))(1.0) for i in 1:N]
for n in (1, 2, 3, 4, 5, 8, 16, 64)
    v = cyc(n); p = pcyc(n)
    SC.total(v); PS.ptotal(p)
    t = @belapsed SC.total($v); tp = @belapsed PS.ptotal($p)
    a = @allocated SC.total(v); ap = @allocated PS.ptotal(p)
    println(mode, "  n = ", lpad(n, 2), "  Dynamic ", lpad(round(1e9 * t / N; digits = 2), 6), " ns/elt ", lpad(round(a / N; digits = 1), 5),
            " B/elt   plain ", lpad(round(1e9 * tp / N; digits = 2), 6), " ns/elt ", lpad(round(ap / N; digits = 1), 5), " B/elt")
end
only(i) = Dynamic{SC.Shape}[SC.mk(getfield(SC, Symbol(:H, i))(1.0)) for _ in 1:N]
for i in (1, 4, 5, 64)
    v = only(i); SC.total(v)
    t = @belapsed SC.total($v)
    println(mode, "  only H", i, ":  Dynamic ", lpad(round(1e9 * t / N; digits = 2), 6), " ns/elt  ", @allocated(SC.total(v)) / N, " B/elt")
end
# sizes: what a Dynamic element costs in memory
v = cyc(4)
println("sizeof(Dynamic{Shape}) = ", sizeof(Dynamic{SC.Shape}), "; kept object type size = ", Base.summarysize(v) / N, " B/elt (summarysize), plain ", Base.summarysize(pcyc(4)) / N)
# the split as compiled: count isa branches in total's code
ct = code_typed(SC.total, Tuple{Vector{Dynamic{SC.Shape}}})[1][1]
nisa = count(s -> occursin("isa", sprint(show, s)), ct.code)
ninv = count(s -> occursin("invoke", sprint(show, s)), ct.code)
ndyn = count(s -> (str = sprint(show, s); occursin("area", str) && !occursin("invoke", str)), ct.code)
println("total's code: ", length(ct.code), " statements, isa checks ", nisa, ", invokes ", ninv, ", generic area calls ", ndyn)
# construction cost: wrapping a plain value as Dynamic
h = SC.H1(1.0)
println("Dynamic{Shape}(H1) construction: ", round(1e9 * @belapsed(SC.mk($h)); digits = 1), " ns, ", @allocated(SC.mk(h)), " B")
