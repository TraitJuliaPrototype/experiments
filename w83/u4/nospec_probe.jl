# E-256 side probe: does a typed caller make `f(@nospecialize x)` specialize, when f is not inlined?
const SETTING = Base.Compiler.NativeInterpreter().facts ? "all" : "product"
struct Q1; a::Float64; end; struct Q2; a::Float64; end; struct Q3; a::Float64; end; struct Q4; a::Float64; end
qa(s::Q1) = s.a; qa(s::Q2) = 2s.a; qa(s::Q3) = 3s.a; qa(s::Q4) = 4s.a
small(@nospecialize x) = qa(x) + 1.0
@noinline big(@nospecialize x) = qa(x) + 1.0
c1(x) = small(x); c2(x) = big(x)
mis(f) = [(mi.specTypes, isdefined(mi, :cache)) for m in methods(f) for mi in Base.specializations(m)]
for T in (Q1, Q2, Q3); c1(T(1.0)); c2(T(1.0)); end
println(SETTING, "  small (inlineable): ", mis(small))
println(SETTING, "  big (@noinline):    ", mis(big))
ct = code_typed(c2, (Q1,))[1]; println(SETTING, "  c2 at Q1: ", ct[1].code, " => ", ct[2])
ct = code_typed(c1, (Q1,))[1]; println(SETTING, "  c1 at Q1: ", ct[1].code, " => ", ct[2])
