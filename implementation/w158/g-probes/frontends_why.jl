# Open issue 250: why the front ends' last call infers Any. For the calls that take the problem's system object
# (`sys::Any`, an operation's declared result `system(x)::Any`): the callee's owner-only flag, whether the call's
# signature is a fact (compiler §1.2), and what plain inference and the facts inference give.
# Run: $JN --project=$ENVG $W158/g-probes/frontends_why.jl
include(joinpath(@__DIR__, "frontends.jl"))
const CC = TraitWorld.CC
w = Base.get_world_counter()
names_t = Union{Nothing, Dynamic{ODE.ODECore.IndexProvider{Symbol}}}
calls = Any[
    ("nl_with_problem at sys::Any", Tuple{typeof(TNS.nl_with_problem), TNS.NLCoreSolution{Float64}, typeof(nlp), Any}),
    ("nl_with_problem at sys::Nothing", Tuple{typeof(TNS.nl_with_problem), TNS.NLCoreSolution{Float64}, typeof(nlp), Nothing}),
    ("with_problem at sys::Any", Tuple{typeof(OC.with_problem), OC.CoreSolution{Float64}, typeof(odp), Any, names_t, Vector{Float64}, Vector{Vector{Float64}}}),
    ("_system(nlp)", Tuple{typeof(OC._system), typeof(nlp)}),
    ("_system(odp)", Tuple{typeof(OC._system), typeof(odp)}),
]
for (name, tt) in calls
    F = tt.parameters[1]
    println("\n== ", name, "\n   ", tt)
    println("   owner-only: ", CC.is_owner_only(F), "; a fact: ", CC.is_fact_sig(tt))
    println("   exported from its module: ", Base.isexported(parentmodule(F.instance), nameof(F.instance)),
            "; public: ", Base.ispublic(parentmodule(F.instance), nameof(F.instance)))
    for facts in (false, true)
        interp = CC.NativeInterpreter(w; facts)
        r = try Base.infer_return_type(F.instance, Tuple{tt.parameters[2:end]...}; interp) catch e; e end
        println("   facts = ", facts, ": ", r)
    end
    ms = Base._methods_by_ftype(tt, -1, w)
    println("   methods at these types: ", ms === nothing ? "?" : length(ms))
end
# the statement in the inner solve_ode (with entered callbacks)
for (name, tt) in (("solve_ode inner", (typeof(odp), typeof(ts), OC.EnteredCallbacks{Vector{Float64}, Float64, Vector{Float64}}, typeof(sopts))),)
    println("\n== ", name, ": ", Base.infer_return_type(OC.solve_ode, tt))
    for (src, r) in Base.code_typed(OC.solve_ode, tt; optimize = false)
        for (i, st) in enumerate(src.code)
            println("     %", i, " = ", st, " :: ", src.ssavaluetypes[i])
        end
    end
end

# the constructor calls that take `sys::Any` inside nl_with_problem and with_problem
NS = TNS.NonlinearSolution{Float64, Vector{Float64}}
OS = OC.ODESolution{Float64, Vector{Float64}}
ctors = Any[
    ("NonlinearSolution{T,P}(…, sys::Any)", Tuple{Type{NS}, Vector{Float64}, Vector{Float64}, Symbol, TNS.NLStats, typeof(nlp), Any}),
    ("NonlinearSolution{T,P}(…, sys::Nothing)", Tuple{Type{NS}, Vector{Float64}, Vector{Float64}, Symbol, TNS.NLStats, typeof(nlp), Nothing}),
]
for (name, tt) in ctors
    println("\n== ", name, "\n   owner-only: ", CC.is_owner_only(tt.parameters[1]), "; a fact: ", CC.is_fact_sig(tt))
    for facts in (false, true)
        interp = CC.NativeInterpreter(w; facts)
        println("   facts = ", facts, ": ", Base.infer_return_type(NS, Tuple{tt.parameters[2:end]...}; interp))
    end
end
println("\nNonlinearSolution exported from TNS: ", Base.isexported(TNS, :NonlinearSolution),
        "; ODESolution exported from ODECore: ", Base.isexported(OC, :ODESolution))
println("\nwith_problem's statements at sys::Any (facts):")
for (src, r) in Base.code_typed(OC.with_problem, (OC.CoreSolution{Float64}, typeof(odp), Any, names_t, Vector{Float64}, Vector{Vector{Float64}}); optimize = false)
    for (i, st) in enumerate(src.code)
        println("     %", i, " = ", st, " :: ", src.ssavaluetypes[i])
    end
end
println("\nnl_with_problem's statements at sys::Any (facts):")
for (src, r) in Base.code_typed(TNS.nl_with_problem, (TNS.NLCoreSolution{Float64}, typeof(nlp), Any); optimize = false)
    for (i, st) in enumerate(src.code)
        println("     %", i, " = ", st, " :: ", src.ssavaluetypes[i])
    end
end

# the same shape in a trait module, with and without a declared result (what the port would write)
module FT
using TraitWorld
@trait_module
struct Sol{T}; u::Vector{T}; sys::Any; end
wrapit(u::Vector{T}, @nospecialize(sys)) where {T} = Sol{T}(u, sys)
wrapit_declared(u::Vector{T}, @nospecialize(sys)) where {T} = Sol{T}(u, sys)::Sol{T}
front(u::Vector{Float64}, x) = wrapit(u, getsys(x))
front_declared(u::Vector{Float64}, x) = wrapit_declared(u, getsys(x))
getsys(@nospecialize(x)) = Base.inferencebarrier(x)
end
println("\nthe shape in a trait module:")
for f in (FT.front, FT.front_declared)
    println("   ", f, "(::Vector{Float64}, ::Int): ", Base.infer_return_type(f, (Vector{Float64}, Int)))
end
println("\nfully_typed(TNS.solve_nonlinear) in this session:")
show(stdout, MIME"text/plain"(), TraitWorld.fully_typed(TNS.solve_nonlinear, (typeof(nlp), typeof(nr), typeof(opts))))
println()
