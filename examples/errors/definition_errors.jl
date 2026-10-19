# Errors at definition against deep stack traces (the review's example 5, in a small library
# rather than TraitDifferentialEquations, whose route A the solvers agent writes): the same user
# and library mistakes in a trait library and in its plain twin. For each: where it is caught
# (library definition, conformance, entry, run time), the message's lines and frames, and
# whether it names what is required.
#
#     julia --project=../env definition_errors.jl          (SHOW=1 prints every message)
#
# Expected (design.md §4.1, §4.7, rule 3):
#   1 missing operation:        at `@implement`, naming the operation and the trait; plain: a
#                               MethodError at run time inside the solver loop.
#   2 wrong result type:        at `@implement` or at the first call, naming the declared type;
#                               plain: accepted silently.
#   3 wrong argument types:     at `@implement` (no method at the declared signature); plain: a
#                               MethodError at run time.
#   4 library reads an undeclared field: at the trait module's end (definition checking), before
#                               any user type exists; plain: an error at the first call with a type
#                               that lacks the field.
#   5 a Float64 cache in a ComplexF64 model: at run time in both (inference cannot prove it), the
#                               trait form with no more frames than the plain one.
include(joinpath(@__DIR__, "..", "common.jl"))
using TraitWorld
SHOW = get(ENV, "SHOW", "0") == "1"
struct Seen; where::Symbol; err::Any; msg::String; lines::Int; frames::Int; end
"Run `f` and classify: `where` is the phase given by the caller once `f` raises."
function seen(f, where::Symbol)
    try
        f(); return Seen(:none, nothing, "", 0, 0)
    catch e
        bt = catch_backtrace()
        while e isa LoadError; e = e.error; end
        msg = sprint((io, e, bt) -> showerror(IOContext(io, :limit => false), e, bt), e, bt)
        ls = split(msg, '\n')
        SHOW && println("---- ", where, "\n", msg, "\n----")
        return Seen(where, e, msg, length(ls), count(l -> occursin(r"^\s*\[\d+\]", l), ls))
    end
end
show1(name, s::Seen) = println("     ", rpad(name, 44), s.where === :none ? "no error" :
    "$(s.where): $(nameof(typeof(s.err))), $(s.lines) lines, $(s.frames) frames; first line: $(first(split(s.msg, '\n'), 1)[1][1:min(end, 110)])")

# the library and its plain twin: an explicit Euler integrator over a model
toplevel(quote
    @trait_module module Mini
    using TraitWorld
    export Model, rhs!, euler
    @trait Model{T} begin
        rhs!(m::Model{T}, du::Vector{T}, u::Vector{T}, t::Float64)::Nothing
    end
    function euler(m::Model, u0::Vector, n::Int, dt::Float64)
        u = copy(u0); du = similar(u); t = 0.0
        for _ in 1:n
            rhs!(m, du, u, t); u .+= dt .* du; t += dt
        end
        return u
    end
    end
    module PlainMini
    function peuler(m, u0::Vector, n::Int, dt::Float64)
        u = copy(u0); du = similar(u); t = 0.0
        for _ in 1:n
            prhs!(m, du, u, t); u .+= dt .* du; t += dt
        end
        return u
    end
    function prhs! end
    end
end)

# 1. a missing operation
toplevel(:(struct Decay1; k::Float64; end))
s1 = seen(() -> toplevel(:(@implement Mini.Model{Float64} Decay1)), :conformance)
p1 = seen(() -> Main.PlainMini.peuler(Main.Decay1(1.0), [1.0], 10, 0.1), :runtime)
show1("1 missing operation (trait)", s1); show1("1 missing operation (plain)", p1)
check("1 trait: caught at the conformance, naming rhs! and the trait", s1.where === :conformance && occursin("rhs!", s1.msg) && occursin("Model", s1.msg))
# (a conformance error lists what is required, so it may be longer than plain's MethodError; it must say more)
check("1 trait: names the declared signature of what is missing", occursin("rhs!(::", s1.msg) && occursin("Vector{Float64}", s1.msg), first(s1.msg, 200))

# 2. a wrong result type: rhs! returns du instead of nothing
toplevel(quote
    struct Decay2; k::Float64; end
    Mini.rhs!(m::Decay2, du::Vector{Float64}, u::Vector{Float64}, t::Float64) = (du .= -m.k .* u)
    Main.PlainMini.prhs!(m::Decay2, du, u, t) = (du .= -m.k .* u)
end)
s2 = seen(() -> toplevel(:(@implement Mini.Model{Float64} Decay2)), :conformance)
s2.where === :none && (s2 = seen(() -> Base.invokelatest(Main.Mini.euler, Main.Decay2(1.0), [1.0], 10, 0.1), :entry))
p2 = seen(() -> Main.PlainMini.peuler(Main.Decay2(1.0), [1.0], 10, 0.1), :runtime)
show1("2 wrong result type (trait)", s2); show1("2 wrong result type (plain)", p2)
check("2 trait: caught at the conformance or the first call, naming the declared result Nothing", s2.where in (:conformance, :entry) && occursin("Nothing", s2.msg),
      "where $(s2.where)")
check("2 plain: accepted silently (nothing checks a result)", p2.where === :none)

# 3. wrong argument types: rhs! only for Vector{Int}
toplevel(quote
    struct Decay3; k::Float64; end
    Mini.rhs!(m::Decay3, du::Vector{Int}, u::Vector{Int}, t::Float64) = nothing
    Main.PlainMini.prhs!(m::Decay3, du::Vector{Int}, u::Vector{Int}, t::Float64) = nothing
end)
s3 = seen(() -> toplevel(:(@implement Mini.Model{Float64} Decay3)), :conformance)
p3 = seen(() -> Main.PlainMini.peuler(Main.Decay3(1.0), [1.0], 10, 0.1), :runtime)
show1("3 wrong argument types (trait)", s3); show1("3 wrong argument types (plain)", p3)
check("3 trait: caught at the conformance, naming rhs! and the declared argument types", s3.where === :conformance && occursin("rhs!", s3.msg) && occursin("Vector{Float64}", s3.msg))

# 4. the library reads a field the trait does not declare
s4 = seen(() -> toplevel(quote
    @trait_module module Mini4
    using TraitWorld, ..Mini
    rate(m::Model) = m.k                       # undeclared: the bound sees rhs! only
    end
end), :definition)
if s4.where === :none
    # definition checking at the prompt warns (design.md §4.7); the call raises
    toplevel(quote struct Decay4; k::Float64; end; Mini.rhs!(m::Decay4, du, u, t) = nothing; @implement Mini.Model{Float64} Decay4 end)
    s4 = seen(() -> Base.invokelatest(Main.Mini4.rate, Main.Decay4(1.0)), :entry)
end
# plain: nothing complains until a user type without the field arrives
p4 = seen(() -> (toplevel(quote module PlainMini4; rate(m) = m.k; end; struct NoK; r::Float64; end end);
                 Base.invokelatest(Main.PlainMini4.rate, Base.invokelatest(Main.NoK, 1.0))), :runtime)
show1("4 undeclared field (trait library)", s4); show1("4 undeclared field (plain library)", p4)
check("4 trait: caught at the library's definition (or warned there and raised at the call), naming the field and the bound",
      s4.where in (:definition, :entry) && occursin("k", s4.msg) && occursin("Model", s4.msg), "where $(s4.where)")

# 5. a Float64 cache in a ComplexF64 model
toplevel(quote
    struct Cached5; cache::Vector{Float64}; end
    Mini.rhs!(m::Cached5, du::Vector{ComplexF64}, u::Vector{ComplexF64}, t::Float64) = (m.cache .= u; du .= -m.cache; nothing)
    Main.PlainMini.prhs!(m::Cached5, du, u, t) = (m.cache .= u; du .= -m.cache; nothing)
end)
c5 = seen(() -> toplevel(:(@implement Mini.Model{ComplexF64} Cached5)), :conformance)
s5 = c5.where === :none ? seen(() -> Base.invokelatest(Main.Mini.euler, Main.Cached5(zeros(1)), [1.0 + 1.0im], 10, 0.1), :runtime) : c5
p5 = seen(() -> Main.PlainMini.peuler(Main.Cached5(zeros(1)), [1.0 + 1.0im], 10, 0.1), :runtime)
show1("5 Float64 cache, complex state (trait)", s5); show1("5 Float64 cache, complex state (plain)", p5)
check("5 trait: an error (at the conformance or at run time)", s5.where !== :none)
# (the entry, a boundary, is one frame plain code does not have)
check("5 trait: at most one frame more than plain (the entry)", s5.frames <= p5.frames + 1, "trait $(s5.frames), plain $(p5.frames)")
summary()
