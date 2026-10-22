# E-157 check 5: a right-hand side that returns `du` (SciML's in-place form with `du .= …` last) is
# refused at its first call under `Dynamic` (`TypeError`), and at the problem's first use under
# `compiled_for` (before any call). A counter in the function says how many calls ran. The same
# for a callable model and for a given Jacobian that returns `J`.
include(joinpath(@__DIR__, "common.jl"))
using ChainModels
header("check 5", "an f that returns du: refused at its first call (Dynamic), at first use (compiled_for)")

const calls = Ref(0)
ret!(du, u, p, t) = (calls[] += 1; du .= -p[1] .* u)          # returns du
struct RetModel; k::Float64; end
(m::RetModel)(du, u, p, t) = (calls[] += 1; du .= -m.k .* u)   # a callable model returning du
lin!(du, u, p, t) = (du .= -p[1] .* u; nothing)
retjac!(J, u, p, t) = (calls[] += 1; J .= 0.0; for i in axes(J, 1); J[i, i] = -p[1]; end; J)   # returns J

firstline(e) = first(split(sprint(showerror, e), '\n'))
function attempt(label, mkprob, alg)
    calls[] = 0
    made = try
        mkprob()
    catch e
        println(rpad(label, 64), "construction raised ", typeof(e), ": ", firstline(e)); return
    end
    e = try
        solve(made, alg); nothing
    catch err
        err
    end
    where_ = e === nothing ? "not refused" : calls[] == 0 ? "before any call (at first use)" : "at call $(calls[])"
    println(rpad(label, 64), rpad(where_, 34), e === nothing ? "" : string(typeof(e), ": ", first(firstline(e), 200)))
    e isa TypeError && println(" "^64, "TypeError expected = ", e.expected, ", got ", typeof(e.got))
end
u0 = [1.0, 2.0]
attempt("function returning du, Dynamic, Tsit5", () -> ODEProblem(ret!, u0, (0.0, 1.0), [0.5]), Tsit5())
attempt("function returning du, Dynamic, Rodas5 (chunk at init)", () -> ODEProblem(ret!, u0, (0.0, 1.0), [0.5]), Rodas5(chunk_size = 0))
attempt("function returning du, compiled_for, Tsit5", () -> ODEProblem(compiled_for(ret!), u0, (0.0, 1.0), [0.5]), Tsit5())
attempt("callable model returning du, Dynamic, Tsit5", () -> ODEProblem(RetModel(0.5), u0, (0.0, 1.0), [0.5]), Tsit5())
attempt("callable model returning du, compiled_for, Tsit5", () -> ODEProblem(compiled_for(RetModel(0.5)), u0, (0.0, 1.0), [0.5]), Tsit5())
attempt("a given Jacobian returning J, Dynamic, Rodas5", () -> ODEProblem(ODEFunction(lin!; jac = retjac!), u0, (0.0, 1.0), [0.5]), Rodas5())
attempt("a given Jacobian returning J, compiled_for, Rodas5", () -> ODEProblem(ODEFunction(lin!; jac = compiled_for(retjac!)), u0, (0.0, 1.0), [0.5]), Rodas5())
footer()
