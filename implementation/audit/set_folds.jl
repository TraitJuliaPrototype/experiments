# The set-folds report (W-171, E-542): does compiled code keep an answer about a set outside the worlds where
# the answer holds? A differential tool. For each case (a shape of two types A, B with a set at some position,
# and a sequence of world changes) it defines the question functions, compiles a copy of each in each world the
# sequence makes, and compares every copy's answer, in every world, with the answer asked afresh there (the
# runtime's own, through `Base.inferencebarrier`, with no fold) and with the shape's own expected answer.
#
#     julia --project=experiments/implementation experiments/implementation/audit/set_folds.jl [options]
#     julia --project=TraitWorld                 experiments/implementation/audit/set_folds.jl --mode=traitworld
# Options:
#     --mode=stub|traitworld   the stub library (default; the runtime's entry points, as the gates) or TraitWorld
#                              (the library's declarations, the kept forms `Dynamic{X}`, `Compiled{T}`, `Callable`,
#                              an operation's declared result, a declared field)
#     --only=<regex>           the cases whose name `shape/sequence` matches
#     --questions=a,b,…        only these questions (sub int eq hasm isa tassert new disp app which)
#     --sample=<n> --seed=<s>  a seeded sample of n cases (the seed is printed)
#     --show=<n>               print n mismatches in full, each with its probe and the code's worlds and edges (20)
#     --probes=<dir>           write each group's first mismatch as a probe file there
#     --shapes=a,b,…           only these shapes (the gate's slice: ../w171/gates/n49_set_folds.jl)
# It asserts nothing. Exit status 0; the last line is the tally. See README.md, "The set-folds report".

using Random

const ARGS_D = Dict{String,String}()
for a in ARGS
    if startswith(a, "--")
        k, v = occursin('=', a) ? split(a[3:end], '='; limit = 2) : (a[3:end], "true")
        ARGS_D[k] = v
    end
end
const MODE = get(ARGS_D, "mode", "stub")
if MODE == "traitworld"
    using TraitWorld
    const LIBNAME = :TraitWorld
else
    using Traits
    const LIBNAME = :Traits
end
const HAS_DELETE = try cglobal(:jl_delete_membership); true catch; false end
const ONLY = haskey(ARGS_D, "only") ? Regex(ARGS_D["only"]) : nothing
const SHAPESEL = haskey(ARGS_D, "shapes") ? split(ARGS_D["shapes"], ',') : nothing
const SHOW = parse(Int, get(ARGS_D, "show", "20"))
const PROBES = get(ARGS_D, "probes", "")

## The shapes ---------------------------------------------------------------------------------------------------
# A shape names the pair whose membership varies (`member` in `set`), the definitions, the two types A and B, a
# value under A for the questions about a value (`val`), the static type of the code compiled once (`W`, the
# argument of a `@nospecializeinfer` method), and the expected answer of `A <: B` given whether the pair holds.
# Names a shape may use: X (the pair's set), S (a member struct), Ph{T} (a phantom struct), Yc and Zc (the sets of
# the transitive sequences; declared in every case).
Base.@kwdef struct Shape
    name::String
    defs::String                 # after `@trait X`, `@trait Yc`, `@trait Zc`, `struct Ph{T} end`
    member::String = "S"         # the pair's member pattern
    set::String = "X"            # the pair's set instance
    setup::String = ""           # memberships in force from the start (before the first world)
    A::String
    B::String
    val::String = ""             # a value whose type is under A ("" where A has none)
    W::String = ""               # the static type of the code compiled once ("" for none)
    sub::Function                # m -> the expected `A <: B` (m: the pair holds)
    valsub::Union{Nothing,Function} = nothing # (m, value index) -> the expected `val isa B` (default sub)
    eq::Union{Nothing,Function} = nothing     # m -> the expected `A == B`, where known
    late::Bool = false           # the methods at B are defined before the member type
    seqs::Symbol = :member       # :member (the generic sequences) or :unmet (a member type defined later)
    traitworld::Bool = false     # only with TraitWorld
    val2::String = ""            # a second value, made by the change :typeT2
    decl::String = ""            # traitworld: the declaration of the pair, `{set}` and `{member}` replaced
    onlyseqs::Vector{String} = String[]  # where not empty, only these sequences
    stub::Bool = true            # also in the stub mode
    warm::String = ""            # a value under W in every world: the code compiled once is first compiled with it
end

# a type or value nested `n` levels in tuples (the runtime's walks stop at 8)
nest(s, n) = n == 0 ? s : "Tuple{" * nest(s, n - 1) * "}"
nestv(s, n) = n == 0 ? s : "(" * nestv(s, n - 1) * ",)"

const SHAPES = Shape[
    Shape(name = "type", defs = "struct S end", A = "S", B = "X", val = "S()", sub = m -> m),
    Shape(name = "late_member", defs = "struct S end", A = "S", B = "X", val = "S()", sub = m -> m, late = true),
    Shape(name = "tuple", defs = "struct S end", A = "Tuple{S}", B = "Tuple{X}", val = "(S(),)", sub = m -> m),
    Shape(name = "tuple2", defs = "struct S end", A = "Tuple{Int, S}", B = "Tuple{Integer, X}", val = "(1, S())", sub = m -> m),
    Shape(name = "invariant", defs = "struct S end", A = "Ph{S}", B = "Ph{X}", val = "Ph{S}()", sub = m -> false),
    Shape(name = "union", defs = "struct S end", A = "S", B = "Union{X, Int}", val = "S()", sub = m -> m),
    Shape(name = "union_both", defs = "struct S end", A = "Union{S, Int}", B = "Union{X, Int}", sub = m -> m),
    Shape(name = "intersection", defs = "struct S end\n@trait Yb", setup = "@implement Yb S", A = "S",
          B = "Core.All{Tuple{X, Yb}}", val = "S()", sub = m -> m),
    Shape(name = "upper_bound", defs = "struct S end", A = "Ph{S}", B = "Ph{<:X}", val = "Ph{S}()", sub = m -> m),
    Shape(name = "lower_bound", defs = "struct S end", A = "Ph{X}", B = "Ph{T} where T>:S", val = "Ph{X}()", sub = m -> m),
    # both bounds, consistent in every world (Julia answers a variable whose lower bound is not under its upper bound as
    # any other: `Ph{S} <: Ph{T} where S<:T<:X` holds whether or not S <: X)
    Shape(name = "both_bounds", defs = "struct S end\nconst UXS = Union{X, S}", A = "Ph{X}", B = "Ph{T} where S<:T<:UXS",
          val = "Ph{X}()", sub = m -> m),
    Shape(name = "lower_bound_eq", defs = "struct S end", A = "Ph{T} where T>:X", B = "Ph{T} where T>:Union{X, S}",
          sub = m -> m, eq = m -> m),
    # inside an invariant parameter two types are equal by their declared structure, in every world (compiler §4.5)
    Shape(name = "lower_bound_inv", defs = "struct S end\nconst UXS = Union{X, S}",
          A = "Ph{Ph{T} where T>:X}", B = "Ph{Ph{T} where T>:UXS}", val = "Ph{Ph{T} where T>:X}()", sub = m -> false),
    Shape(name = "lower_bound_rev", defs = "struct S end\nstruct S2 end\n@trait Yb", setup = "@implement Yb S2",
          A = "Tuple{S2, Ph{X}}", B = "Tuple{Yb, Ph{T}} where T>:S", val = "(S2(), Ph{X}())", sub = m -> m),
    Shape(name = "super_param", defs = "struct S end\nabstract type AP{T} end\nstruct P2{T} <: AP{T} end",
          A = "P2{S}", B = "AP{<:X}", val = "P2{S}()", sub = m -> m),
    Shape(name = "type_type", defs = "struct S end", A = "Type{S}", B = "Type{<:X}", val = "S", sub = m -> m),
    Shape(name = "type_value", defs = "struct S end", member = "Type{S}", A = "Type{S}", B = "X", val = "S", sub = m -> m),
    Shape(name = "vararg", defs = "struct S end", A = "Tuple{Int, S, S}", B = "Tuple{Int, Vararg{X}}", val = "(1, S(), S())", sub = m -> m),
    Shape(name = "family", defs = "struct F{T} end", member = "F{T} where T", A = "F{Int}", B = "X", val = "F{Int}()", sub = m -> m),
    Shape(name = "family_bounded", defs = "struct F{T} end\n@trait Yb\nstruct S end", setup = "@implement Yb S",
          member = "F{T} where T<:Yb", A = "F{S}", B = "X", val = "F{S}()", sub = m -> m),
    Shape(name = "input", defs = "@trait X2{I}\nccall(:jl_set_input_params, Cvoid, (Any, UInt8), X2, 0x01)\nstruct S end",
          set = "X2{Int}", A = "S", B = "X2{Int}", val = "S()", sub = m -> m),
    Shape(name = "input_ub", defs = "@trait X2{I}\nccall(:jl_set_input_params, Cvoid, (Any, UInt8), X2, 0x01)\nstruct S end",
          set = "X2{Int}", A = "S", B = "X2{<:Integer}", val = "S()", sub = m -> m),
    Shape(name = "input_other", defs = "@trait X2{I}\nccall(:jl_set_input_params, Cvoid, (Any, UInt8), X2, 0x01)\nstruct S end",
          set = "X2{Int}", A = "S", B = "X2{String}", val = "S()", sub = m -> false),
    Shape(name = "abstract_member", defs = "abstract type AM end\nstruct SA <: AM end", member = "AM",
          A = "AM", B = "X", val = "SA()", W = "AM", sub = m -> m),
    Shape(name = "set_member", defs = "@trait Y0\nstruct S0 end", setup = "@implement Y0 S0", member = "Y0",
          A = "Y0", B = "X", val = "S0()", W = "Y0", sub = m -> m),
    Shape(name = "unmet", defs = "abstract type AM end\nstruct S0 end", setup = "@implement X S0", member = "",
          A = "X", B = "AM", val = "S0()", W = "X", sub = m -> false, valsub = (m, vi) -> vi == 2,
          seqs = :unmet, val2 = "T2()"),
    # E-544: a lower bound below a position's top, and a member inside a lower bound (compiler §5.5)
    Shape(name = "lb_tuple", defs = "struct S end", A = "Tuple{Ph{X}}", B = "Tuple{Ph{T}} where T>:S",
          val = "(Ph{X}(),)", sub = m -> m),
    Shape(name = "lb_union", defs = "struct S end", A = "Ph{X}", B = "Union{Int, Ph{T} where T>:S}",
          val = "Ph{X}()", sub = m -> m),
    Shape(name = "lb_vararg", defs = "struct S end", A = "Tuple{Int, Ph{X}}", B = "Tuple{Int, Vararg{Ph{T}}} where T>:S",
          val = "(1, Ph{X}())", sub = m -> m),
    Shape(name = "lb_in_union", defs = "struct S end", A = "Ph{Union{X, Int}}", B = "Ph{T} where T>:Union{S, Int}",
          val = "Ph{Union{X, Int}}()", sub = m -> m),
    Shape(name = "lb_in_tuple", defs = "struct S end", A = "Ph{Tuple{X}}", B = "Ph{T} where T>:Tuple{S}",
          val = "Ph{Tuple{X}}()", sub = m -> m),
    # past the depth of the runtime's walks (8): the set nine tuples deep, and a lower bound there
    Shape(name = "deep9", defs = "struct S end", A = nest("S", 9), B = nest("X", 9), val = nestv("S()", 9), sub = m -> m),
    Shape(name = "deep9_lb", defs = "struct S end", A = nest("Ph{X}", 9), B = nest("Ph{T}", 9) * " where T>:S",
          val = nestv("Ph{X}()", 9), sub = m -> m),
    # an intersection of three components; two instances of one set at different inputs
    Shape(name = "all3", defs = "struct S end\n@trait Yb\n@trait Yd", setup = "SFLIB_DECLARE(S, Yb)\nSFLIB_DECLARE(S, Yd)",
          A = "S", B = "Core.All{Tuple{X, Yb, Yd}}", val = "S()", sub = m -> m),
    Shape(name = "inputs2", defs = "@trait X2{I}\nccall(:jl_set_input_params, Cvoid, (Any, UInt8), X2, 0x01)\nstruct S end",
          setup = "SFLIB_DECLARE(S, X2{String})", set = "X2{Int}", A = "S", B = "Core.All{Tuple{X2{Int}, X2{String}}}",
          val = "S()", sub = m -> m),
    # a method at the member's own type defined before the membership, and code compiled once at the set (compiler C-166)
    Shape(name = "member_method", defs = "struct S end\nstruct T1 end", setup = "SFLIB_DECLARE(T1, X)", A = "S", B = "X",
          val = "S()", W = "X", warm = "T1()", sub = m -> m),
    Shape(name = "dynamic", defs = "@trait Y0", member = "Y0", A = "Core.Dynamic{Y0}", B = "X",
          sub = m -> m, traitworld = true),
    Shape(name = "compiled", defs = "struct S end", A = "Core.Compiled{S}", B = "X", val = "Core.Compiled{S}(S())",
          sub = m -> m, traitworld = true),
    # a declared field read at a value typed by its set, compiled once at the set (compiler §7.1)
    Shape(name = "field", defs = "struct S; u::Int; end\n@trait XF begin\n    @const u::Int\nend", set = "XF", A = "S", B = "XF",
          val = "S(1)", W = "XF", sub = m -> m, traitworld = true,
          onlyseqs = ["declared", "taken_back", "redeclared", "method_then_member"]),
    # the library's forms of a declaration: a block, a forwarding field, a family by `where`
    Shape(name = "block", defs = "struct S end", A = "S", B = "X", val = "S()", sub = m -> m, traitworld = true,
          decl = "TraitWorld.@implement {set} {member} begin end"),
    Shape(name = "forwarding", defs = "struct S end\nstruct WS; s::S; end", setup = "TraitWorld.@implement X S",
          member = "WS", A = "WS", B = "X", val = "WS(S())", sub = m -> m, traitworld = true,
          decl = "TraitWorld.@implement {set} {member} by s"),
    Shape(name = "family_where", defs = "struct F{T} end", member = "F{T} where T", A = "F{Int}", B = "X",
          val = "F{Int}()", sub = m -> m, traitworld = true, decl = "TraitWorld.@implement {set} F{T} where T"),
    # Callable: a callable struct declared a member of `Callable{Tuple{Int}, Int}` (compiler §7.4)
    Shape(name = "callable", defs = "struct S end\n(s::S)(x::Int) = x", set = "Core.Callable{Tuple{Int}, Int}",
          A = "S", B = "Core.Callable{Tuple{Int}, Int}", val = "S()", sub = m -> m, traitworld = true,
          decl = "TraitWorld.@implement Core.Callable {member}",
          onlyseqs = ["declared", "taken_back", "redeclared", "method_added", "method_deleted", "method_then_member"]),
    # an operation's declared result read at a value typed by the set, with the `trusted` mark (compiler §7.1)
    Shape(name = "operation", defs = "struct S end\n@trait XO begin\n    oval(x::XO)::Int\nend\noval(::S) = 1",
          set = "XO", A = "S", B = "XO", val = "S()", W = "XO", sub = m -> m, traitworld = true,
          onlyseqs = ["declared", "taken_back", "redeclared", "method_added", "method_deleted", "method_then_member"]),
]

## The sequences -------------------------------------------------------------------------------------------------
# A link is a membership: :SX the pair itself; :SY, :YX the path through Yc; :SZ, :ZY, :YX the path through Zc and
# Yc. A change is (:add | :del, link), (:defB | :delB) a method at B, or :typeT2 / :delT2 (the shape :unmet).
struct Seq
    name::String
    setup::Vector{Any}
    changes::Vector{Any}
end
const MEMBER_SEQS = Seq[
    Seq("declared", [], [(:add, :SX)]),
    Seq("taken_back", [], [(:add, :SX), (:del, :SX)]),
    Seq("redeclared", [], [(:add, :SX), (:del, :SX), (:add, :SX)]),
    Seq("path_second", [], [(:add, :SY), (:add, :YX)]),
    Seq("path_second_back", [], [(:add, :SY), (:add, :YX), (:del, :YX)]),
    Seq("path_first_back", [], [(:add, :SY), (:add, :YX), (:del, :SY)]),
    Seq("super1", [(:add, :YX)], [(:add, :SY)]),
    Seq("super1_back", [(:add, :YX)], [(:add, :SY), (:del, :SY)]),
    Seq("super2", [(:add, :ZY), (:add, :YX)], [(:add, :SZ)]),
    Seq("super2_back", [(:add, :ZY), (:add, :YX)], [(:add, :SZ), (:del, :SZ)]),
    Seq("method_added", [(:add, :SX)], [:defB]),
    Seq("method_added_less", [(:add, :SX), :defA], [:defB]),
    Seq("method_deleted", [(:add, :SX), :defB], [:delB]),
    Seq("method_then_member", [], [:defB, (:add, :SX), (:del, :SX)]),
    # E-544: a method at A defined before the membership (C-166); a redeclaration with another receiver
    Seq("method_at_member", [:defA], [(:add, :SX), (:del, :SX)]),
    Seq("redeclared_by", [], [(:add, :SX), (:redecl, :SX)]),
]
const UNMET_SEQS = Seq[
    Seq("type_later", [], [:typeT2]),
    Seq("type_later_back", [], [:typeT2, :delT2]),
]
needs_delete(q::Seq) = any(c -> c isa Tuple && c[1] === :del || c === :delT2, q.changes)
redeclares(q::Seq) = any(c -> c isa Tuple && c[1] === :redecl, q.changes)

## The questions -------------------------------------------------------------------------------------------------
# Each has a body for the compiled copies and a body for the fresh answer; `x` is the value.
const NOARG_Q = [:sub, :int, :eq, :hasm]
const VAL_Q = [:isa, :tassert, :new, :stf, :mrs, :disp, :app, :which, :op, :fld]
const QSEL = haskey(ARGS_D, "questions") ? Symbol.(split(ARGS_D["questions"], ',')) : vcat(NOARG_Q, VAL_Q)
# the operation's question only where the shape declares the operation; the declared field's where it declares one
qsel(sh) = filter(q -> (q !== :op || occursin("oval", sh.defs)) && (q !== :fld || occursin("u::Int\nend", sh.defs)), QSEL)
qbody(q) = q === :sub ? "A <: B" :
           q === :int ? "typeintersect(A, B) === Union{}" :
           q === :eq ? "A == B" :
           q === :hasm ? "hasmethod(h, Tuple{A})" :
           q === :isa ? "x isa B" :
           q === :tassert ? "(x::B; true)" :
           q === :new ? "(@newHB(x); true)" :
           q === :stf ? "(m = MB(); setfield!(m, :v, x); true)" :
           q === :mrs ? "(Core.memoryrefset!(Core.memoryrefnew(Memory{B}(undef, 1)), x, :not_atomic, true); true)" :
           q === :fld ? "x.u" :
           q === :disp ? "g(x)" :
           q === :app ? "applicable(h, x)" :
           q === :which ? "which(g, Tuple{Core.Typeof(x)})" :
           q === :op ? "oval(x)" : error(q)
const IB = "Base.inferencebarrier"
# The fresh answers are asked of the runtime by `ccall`, which neither inference nor code generation folds; dispatch
# by the methods valid in the task's world (a search that is not a leaf query reads no cache) and `jl_subtype` there.
const REF_SRC = raw"""
# the methods of f valid in the task's world, read from the table's definitions (a query that is no leaf type reads no
# dispatch cache), and the one dispatch selects for the argument types `tt` there, by `jl_subtype` and specificity
SF_methods(f) = (ms = Base._methods_by_ftype(Tuple{typeof(f), Vararg{Any}}, -1, Base.tls_world_age());
                 ms === nothing ? Method[] : Method[m.method for m in ms])
function SF_select(f, tt)
    sig = Tuple{typeof(f), tt.parameters...}
    app = [m for m in SF_methods(f) if ccall(:jl_subtype, Cint, (Any, Any), sig, m.sig) != 0]
    isempty(app) && return nothing
    best = [m for m in app if all(o -> o === m || Base.morespecific(m.sig, o.sig), app)]
    return length(best) == 1 ? best[1] : :ambiguous
end
SF_dispatch(f, x) = (m = SF_select(f, Tuple{Core.Typeof(x)}); m isa Method ? Core.invoke(f, Base.tuple_type_tail(m.sig), x) :
                     m === nothing ? :nomethod : m)
SF_hasmethod(f, A) = SF_select(f, Tuple{A}) isa Method
SF_which(f, x) = (m = SF_select(f, Tuple{Core.Typeof(x)}); m isa Method ? m : :nomethod)
"""
include_string(Main, REF_SRC)
fbody(q) = q === :sub ? "ccall(:jl_subtype, Cint, (Any, Any), A, B) != 0" :
           q === :int ? "ccall(:jl_type_intersection, Any, (Any, Any), A, B) === Union{}" :
           q === :eq ? "ccall(:jl_types_equal, Cint, (Any, Any), A, B) != 0" :
           q === :hasm ? "Main.SF_hasmethod(h, A)" :
           q === :isa ? "ccall(:jl_isa, Cint, (Any, Any), x, B) != 0" :
           q === :tassert ? "ccall(:jl_isa, Cint, (Any, Any), x, B) != 0 ? true : :TypeError" :
           q === :new ? "(ccall(:jl_new_structv, Any, (Any, Ptr{Any}, UInt32), HB, Any[x], 1); true)" :
           q in (:stf, :mrs) ? "ccall(:jl_isa, Cint, (Any, Any), x, B) != 0 ? true : :TypeError" :
           q === :fld ? "getfield(x, :u)" :
           q === :disp ? "Main.SF_dispatch(g, x)" :
           q === :app ? "Main.SF_dispatch(h, x) !== :nomethod" :
           q === :which ? "Main.SF_which(g, x)" :
           q === :op ? "Main.SF_dispatch(oval, x)" : error(q)
# the dynamic answer (through the runtime's caches) where it differs from the fresh one's path
dbody(q) = q === :disp ? "g($IB(x))" : q === :app ? "applicable($IB(h), $IB(x))" :
           q === :hasm ? "hasmethod($IB(h), $IB(Tuple{A}))" : q === :sub ? "$IB(A) <: $IB(B)" :
           q === :isa ? "Core.isa($IB(x), $IB(B))" : ""

## A case's source -----------------------------------------------------------------------------------------------
link_parts(sh::Shape, l::Symbol) = l === :SX ? (sh.member, sh.set) : l === :SY ? (sh.member, "Yc") :
    l === :YX ? ("Yc", sh.set) : l === :SZ ? (sh.member, "Zc") : l === :ZY ? ("Zc", "Yc") : error(l)
function change_src(sh::Shape, c)
    if c isa Tuple
        mem, set = link_parts(sh, c[2])
        if c[1] === :add
            if MODE == "traitworld"
                d = c[2] === :SX && !isempty(sh.decl) ? sh.decl : "TraitWorld.@implement {set} {member}"
                return replace(d, "{set}" => set, "{member}" => mem)
            end
            return "SFLIB_DECLARE($mem, $set)"
        elseif c[1] === :redecl
            # the runtime's entry point, with the receiver `:none` (the first declaration's is `:self`)
            return "Traits.declare_membership($mem, $set, @__MODULE__, nothing, :none)"
        else
            MODE == "traitworld" && return "TraitWorld.delete_membership($set, $mem)"
            return "ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), $mem, $set, @__MODULE__)"
        end
    elseif c === :defB
        return "g(::B) = :B\nh(::B) = :hB"
    elseif c === :defA
        return "g(::A) = :A"
    elseif c === :delB
        return "Base.delete_method(only(filter(m -> m.sig == Tuple{typeof(g), B}, methods(g).ms)))\n" *
               "Base.delete_method(only(filter(m -> m.sig == Tuple{typeof(h), B}, methods(h).ms)))"
    elseif c === :typeT2
        return "struct T2 <: AM end\nSFLIB_DECLARE(T2, X)"
    elseif c === :delT2
        return "ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), T2, X, @__MODULE__)"
    end
    error("change $c")
end
change_name(c) = c isa Tuple ? "$(c[1])_$(c[2])" : string(c)

# the declaration: the library's macro where the member is a plain type name, else the runtime's entry point
function declare_fn()
    if LIBNAME === :TraitWorld
        return (mem, set, mod) -> Core.eval(mod, :(TraitWorld.@implement $(set) $(mem)))
    end
    return (mem, set, mod) -> Traits.declare_membership(mem, set, mod)
end

function case_src(sh::Shape, q::Seq, ncopies::Int)
    io = IOBuffer()
    println(io, "@trait X\n@trait Yc\n@trait Zc\nstruct Ph{T} end")
    hasB = !(:defB in q.changes) && !(:defB in q.setup)   # a method deleted would bring back one it replaced
    if sh.late
        println(io, "g(::Any) = :Any\ng(::X) = :B\nh(::X) = :hB")
    end
    println(io, sh.defs)
    println(io, "const A = ", sh.A, "\nconst B = ", sh.B)
    if !sh.late
        println(io, "g(::Any) = :Any")
        hasB && println(io, "g(::B) = :B\nh(::B) = :hB")
    end
    println(io, "function g end\nfunction h end")
    println(io, "struct HB; v::B; end\nmacro newHB(x) esc(Expr(:new, :HB, x)) end")
    println(io, "mutable struct MB; v::B; MB() = new(); end")
    for k in 0:ncopies-1
        for qq in qsel(sh)
            if qq in NOARG_Q
                println(io, "q_$(qq)_$(k)() = ", qbody(qq))
                println(io, "r_$(qq)_$(k)() = q_$(qq)_$(k)()")
            else
                println(io, "q_$(qq)_$(k)(x) = ", qbody(qq))
                println(io, "r_$(qq)_$(k)(x) = q_$(qq)_$(k)(x)")
                if !isempty(sh.W)
                    println(io, "Base.@nospecializeinfer o_$(qq)_$(k)(@nospecialize(x::$(sh.W))) = ", qbody(qq))
                    println(io, "ro_$(qq)_$(k)(x) = o_$(qq)_$(k)(x)")
                end
            end
        end
    end
    for qq in qsel(sh)
        if qq in NOARG_Q
            println(io, "f_$(qq)() = ", fbody(qq))
        else
            println(io, "f_$(qq)(x) = ", fbody(qq))
            d = dbody(qq)
            isempty(d) || println(io, "d_$(qq)(x) = ", d)
        end
    end
    println(io, "SFW(x) = Core.isa($IB(x), $IB($(isempty(sh.W) ? "Any" : sh.W)))")
    return String(take!(io))
end

## Running a case ------------------------------------------------------------------------------------------------
# A check: one compiled copy (`copy`: first compiled after change `copy`), one form, asked in world `world` (after
# change `world`), at the value `vi`; `where_` :latest (asked when that world was the latest) or :cross (afterwards,
# by `Base.invoke_in_world`). Answers are kept as their `repr`.
struct Check
    case::String; shape::String; seq::String; question::Symbol; form::String
    copy::Int; world::Int; vi::Int; where_::Symbol
    compiled::String; fresh::String; expected::String; dynamic::String
end
const SKIPPED = String[]

gg(M, s) = Base.invokelatest(getglobal, M, s)
excname(e) = e isa MethodError ? :MethodError : e isa TypeError ? :TypeError : Symbol(nameof(typeof(e)))
callv(f, args...) = try f(args...) catch e; excname(e) end
latest(f, args...) = callv(Base.invokelatest, f, args...)
inworld(w, f, args...) = callv(Base.invoke_in_world, w, f, args...)
isexc(x) = x isa Symbol && x in (:MethodError, :TypeError, :ErrorException, :ArgumentError)

# The code that would run for `f` at `args` in world `w`, where one is cached: a CodeInstance of the default owner
# whose worlds hold `w`, at an instance whose signature covers the arguments' types.
function cached_ci(f, w::UInt, args)
    tt = Tuple{map(Core.Typeof, args)...}
    for m in methods(f), mi in Base.specializations(m)
        isdefined(mi, :cache) || continue
        Tuple{typeof(f), tt.parameters...} <: mi.specTypes || continue
        ci = mi.cache
        while true
            ci.owner === nothing && ci.min_world <= w <= ci.max_world && return ci
            isdefined(ci, :next) || break
            ci = ci.next
        end
    end
    return nothing
end
# Runs compiled code, but not where it would end in `unreachable`: code whose result is `Union{}` (it always
# throws) where the fresh answer returns runs on past the test it folded, into the trap. That is a mismatch, kept
# as `:would_trap`, without running it.
function compiled_call(f, w::Union{Nothing,UInt}, fresh, args...)
    wq = w === nothing ? Base.get_world_counter() : w
    ci = cached_ci(f, wq, args)
    if ci !== nothing && ci.rettype === Union{} && !isexc(fresh)
        return :would_trap
    end
    return w === nothing ? latest(f, args...) : inworld(w, f, args...)
end

function links_hold(links::Set{Symbol})
    :SX in links || (:SY in links && :YX in links) || (:SZ in links && :ZY in links && :YX in links)
end

function expected(sh::Shape, q::Symbol, m::Bool, vi::Int, mstate)
    s = sh.sub(m)
    vs = sh.valsub === nothing ? s : sh.valsub(m, vi)
    hasA, hasB = mstate
    q === :sub && return s
    q === :isa && return vs
    q === :tassert && return vs ? true : :TypeError
    q === :new && return vs ? true : :TypeError
    q in (:stf, :mrs) && return vs ? true : :TypeError
    q === :eq && return sh.eq === nothing ? missing : sh.eq(m)
    q === :int && return missing          # only one direction is known
    q === :disp && return hasA ? :A : (hasB && vs) ? :B : :Any
    q === :app && return hasB && vs
    q === :hasm && return hasB && s
    return missing
end

normalize(x) = x isa Method ? (x.name, x.sig) : x
r1(x) = replace(repr(normalize(x)), '\t' => ' ', '\n' => ' ')

function run_case(sh::Shape, q::Seq; declare, record)
    cname = "$(sh.name)/$(q.name)"
    ncopies = length(q.changes) + 1
    src = case_src(sh, q, ncopies)
    M = Module(Symbol("SF_", replace(cname, '/' => "__")))
    Core.eval(M, :(using $(LIBNAME)))
    Core.eval(M, :(SFLIB_DECLARE(mem, set) = $(declare)(mem, set, $M)))
    include_string(M, src)
    # the setup
    links = Set{Symbol}()
    hasA = false; hasB = !(:defB in q.changes) && !(:defB in q.setup); t2 = false
    isempty(sh.setup) || include_string(M, sh.setup)
    for c in q.setup
        include_string(M, change_src(sh, c))
        c isa Tuple && push!(links, c[2])
        c === :defA && (hasA = true)
        c === :defB && (hasB = true)
    end
    worlds = UInt[Base.get_world_counter()]
    states = Any[(links_hold(links), (hasA, hasB), t2)]
    vals = Any[]
    isempty(sh.val) || push!(vals, Base.invokelatest(Core.eval, M, Meta.parse(sh.val)))
    val2 = Ref{Any}(nothing)
    forms_for(qq) = qq in NOARG_Q ? ["r", "q"] : (isempty(sh.W) ? ["r", "q"] : ["r", "q", "ro", "o"])
    fn(form, qq, k) = gg(M, Symbol(form, "_", qq, "_", k))
    vlist() = begin
        vs = Tuple{Int,Any}[]
        isempty(vals) || push!(vs, (1, vals[1]))
        val2[] === nothing || push!(vs, (2, val2[]))
        vs
    end
    info = (M = M, worlds = worlds, states = states)
    warmv = isempty(sh.warm) ? nothing : Base.invokelatest(Core.eval, M, Meta.parse(sh.warm))
    function ask(where_, k, j, w)
        # a new copy's code compiled once at W, first with a value under W in every world (compiler C-166)
        if warmv !== nothing && where_ === :latest && k == j
            for qq in qsel(sh), form in ("o", "ro")
                qq in NOARG_Q || latest(fn(form, qq, k), warmv)
            end
        end
        m, mstate, _ = states[j+1]
        for qq in qsel(sh)
            if qq in NOARG_Q
                fr = w === nothing ? latest(gg(M, Symbol("f_", qq))) : inworld(w, gg(M, Symbol("f_", qq)))
                ex = expected(sh, qq, m, 1, mstate)
                for form in forms_for(qq)
                    c = compiled_call(fn(form, qq, k), w, fr)
                    record(Check(cname, sh.name, q.name, qq, form, k, j, 0, where_, r1(c), r1(fr), r1(ex), ""), info, ())
                end
            else
                # `which` asks the latest world by its definition: compared where the task runs in it
                (qq === :which && where_ !== :latest) && continue
                for (vi, v) in vlist()
                    fr = w === nothing ? latest(gg(M, Symbol("f_", qq)), v) : inworld(w, gg(M, Symbol("f_", qq)), v)
                    dy = Base.invokelatest(isdefined, M, Symbol("d_", qq)) ? (w === nothing ? latest(gg(M, Symbol("d_", qq)), v) :
                                                                         inworld(w, gg(M, Symbol("d_", qq)), v)) : nothing
                    ex = expected(sh, qq, m, vi, mstate)
                    under_W = w === nothing ? latest(gg(M, :SFW), v) : inworld(w, gg(M, :SFW), v)
                    for form in forms_for(qq)
                        (form in ("o", "ro") && under_W !== true) && continue
                        c = compiled_call(fn(form, qq, k), w, fr, v)
                        record(Check(cname, sh.name, q.name, qq, form, k, j, vi, where_, r1(c), r1(fr), r1(ex),
                                     dy === nothing ? "" : r1(dy)), info, (v,))
                    end
                end
            end
        end
    end
    # copy 0 at the first world
    ask(:latest, 0, 0, nothing)
    for (j, c) in enumerate(q.changes)
        include_string(M, change_src(sh, c))
        if c isa Tuple
            c[1] === :add || c[1] === :redecl ? push!(links, c[2]) : delete!(links, c[2])
        elseif c === :defB
            hasB = true
        elseif c === :delB
            hasB = false
        elseif c === :typeT2
            t2 = true
            val2[] = Base.invokelatest(Core.eval, M, Meta.parse(sh.val2))
        end
        push!(worlds, Base.get_world_counter())
        push!(states, (links_hold(links), (hasA, hasB), t2))
        for k in j:-1:0                 # the new copy first: compiled first in this world
            ask(:latest, k, j, nothing)
        end
    end
    # every copy in every world
    for k in 0:ncopies-1, j in 0:ncopies-1
        ask(:cross, k, j, worlds[j+1])
    end
    return nothing
end

## The code's worlds and edges, for a mismatch -------------------------------------------------------------------
function ci_report(io, M, form, qq, k, w, args)
    f = gg(M, Symbol(form, "_", qq, "_", k))
    tt = Tuple{typeof(f), map(Core.Typeof, args)...}
    for m in methods(f), mi in Base.specializations(m)
        isdefined(mi, :cache) || continue
        tt <: mi.specTypes || continue
        ci = mi.cache
        while true
            if ci.owner === nothing
                es = ci.edges
                names = String[]
                for i in 1:length(es)
                    e = es[i]
                    if e isa Core.MethodInstance && e.def isa Method && e.def.name === :implements
                        push!(names, "membership " * sprint(show, e.def.sig))
                    elseif e === Core.methodtable && i > 1 && es[i-1] isa Type
                        push!(names, "absence " * sprint(show, es[i-1]))
                    elseif e isa Core.CodeInstance
                        push!(names, "code " * sprint(show, e.def.specTypes))
                    elseif e isa Core.MethodInstance
                        push!(names, "instance " * sprint(show, e.specTypes))
                    end
                end
                println(io, "      ", mi.specTypes, "  worlds ", Int(ci.min_world), ":",
                        ci.max_world == typemax(UInt) ? "∞" : Int(ci.max_world),
                        (ci.min_world <= w <= ci.max_world ? "  <- runs in world $(Int(w))" : ""))
                isempty(names) || println(io, "        edges: ", join(names, "; "))
            end
            isdefined(ci, :next) || break
            ci = ci.next
        end
    end
end

## The probe file for a mismatch ---------------------------------------------------------------------------------
function probe_src(c::Check)
    sh = only(filter(s -> s.name == c.shape, SHAPES))
    q = only(filter(s -> s.name == c.seq, vcat(MEMBER_SEQS, UNMET_SEQS)))
    io = IOBuffer()
    println(io, "# set_folds probe: $(c.case), question $(c.question), form $(c.form), copy $(c.copy) (first compiled after change $(c.copy)), world $(c.world)")
    println(io, "# compiled $(repr(c.compiled)) against fresh $(repr(c.fresh)) (expected $(repr(c.expected)))")
    println(io, "#     julia --project=experiments/implementation <this file>")
    println(io, "using Traits\nSFLIB_DECLARE(mem, set) = Traits.declare_membership(mem, set, @__MODULE__)")
    println(io, REF_SRC)
    println(io, "@trait X\n@trait Yc\n@trait Zc\nstruct Ph{T} end")
    sh.late && println(io, "g(::Any) = :Any\ng(::X) = :B\nh(::X) = :hB")
    println(io, sh.defs, "\nconst A = ", sh.A, "\nconst B = ", sh.B)
    if !sh.late
        println(io, "g(::Any) = :Any")
        (:defB in q.changes || :defB in q.setup) || println(io, "g(::B) = :B\nh(::B) = :hB")
    end
    println(io, "function g end\nfunction h end")
    println(io, "struct HB; v::B; end\nmacro newHB(x) esc(Expr(:new, :HB, x)) end")
    println(io, "mutable struct MB; v::B; MB() = new(); end")
    qq = c.question
    arg = qq in NOARG_Q ? "" : "x"
    w = isempty(sh.W) ? "" : sh.W
    if c.form in ("o", "ro")
        println(io, "Base.@nospecializeinfer q(@nospecialize(x::$w)) = ", qbody(qq))
    else
        println(io, "q($arg) = ", qbody(qq))
    end
    println(io, "r($arg) = q($arg)")
    println(io, "fresh($arg) = ", fbody(qq))
    println(io, "call(f, a...) = try f(a...) catch e; nameof(typeof(e)) end")
    isempty(sh.setup) || println(io, sh.setup)
    for ch in q.setup; println(io, change_src(sh, ch)); end
    println(io, "worlds = [Base.get_world_counter()]")
    v = qq in NOARG_Q ? "" : (c.vi == 2 ? "" : sh.val)
    asked = c.form in ("r", "ro") ? "r" : "q"
    vs = c.vi == 2 ? "val2" : (qq in NOARG_Q ? "" : "val")
    qq in NOARG_Q || c.vi == 2 || println(io, "val = ", sh.val)
    c.copy == 0 && println(io, "println(\"compiled in world 0: \", call($asked$(isempty(vs) ? "" : ", $vs")))")
    for (j, ch) in enumerate(q.changes)
        println(io, change_src(sh, ch))
        ch === :typeT2 && println(io, "val2 = ", sh.val2)
        println(io, "push!(worlds, Base.get_world_counter())")
        j == c.copy && println(io, "println(\"compiled in world $j: \", call($asked$(isempty(vs) ? "" : ", $vs")))")
    end
    a = isempty(vs) ? "" : ", $vs"
    println(io, "for j in 0:length(worlds)-1")
    println(io, "    println(\"world \", j, \": compiled \", call(Base.invoke_in_world, worlds[j+1], $asked$a), \", fresh \", call(Base.invoke_in_world, worlds[j+1], fresh$a))")
    println(io, "end")
    return String(take!(io))
end

## Main ----------------------------------------------------------------------------------------------------------
# The parent runs the cases in worker processes (this script with --worker): compiled code that a hole sends into
# `unreachable` ends the process, so a case that ends its worker is kept as a crash and the next worker goes on.
function cases()
    out = Tuple{Shape,Seq}[]
    for sh in SHAPES
        sh.traitworld && MODE != "traitworld" && continue
        SHAPESEL === nothing || sh.name in SHAPESEL || continue
        # the library declares a set's inputs itself; a pattern of a free variable is refused there
        MODE == "traitworld" && (startswith(sh.name, "input") || sh.name == "unmet") && continue
        seqs = sh.seqs === :unmet ? UNMET_SEQS : MEMBER_SEQS
        isempty(sh.onlyseqs) || (seqs = filter(q -> q.name in sh.onlyseqs, seqs))
        for q in seqs
            # the methods at B are part of a late member's definitions
            sh.late && startswith(q.name, "method") && continue
            name = "$(sh.name)/$(q.name)"
            ONLY === nothing || occursin(ONLY, name) || continue
            (redeclares(q) && MODE == "traitworld") && continue
            if needs_delete(q) && !HAS_DELETE
                push!(SKIPPED, "$name (no jl_delete_membership in this build)")
                continue
            end
            push!(out, (sh, q))
        end
    end
    if haskey(ARGS_D, "sample")
        seed = parse(Int, get(ARGS_D, "seed", string(rand(UInt16))))
        println("sample: ", ARGS_D["sample"], " cases, seed ", seed)
        out = shuffle(MersenneTwister(seed), out)[1:min(end, parse(Int, ARGS_D["sample"]))]
    end
    return out
end

kind(where_, copy, world) = where_ == "latest" ? (copy < world ? "kept_after_change" : "first_compiled") :
    copy > world ? "run_in_earlier_world" : copy < world ? "old_copy_in_later_world" : "own_world"

function worker(out::String, from::Int)
    cs = cases()
    declare = declare_fn()
    tsv = open(out * ".tsv", "a")
    det = open(out * ".details", "a")
    seen = Set{Any}()
    function record(c::Check, info, args)
        mm = c.compiled != c.fresh
        db = !isempty(c.dynamic) && c.dynamic != c.fresh
        ob = c.expected != "missing" && c.fresh != c.expected
        println(tsv, join((c.case, c.shape, c.seq, c.question, c.form, c.copy, c.world, c.vi, c.where_,
                           c.compiled, c.fresh, c.expected, c.dynamic, Int(mm), Int(db), Int(ob)), '\t'))
        key = (c.question, c.shape, c.seq)
        if mm && !(key in seen)
            push!(seen, key)
            println(det, "-- $(c.case) $(c.question) form $(c.form) copy $(c.copy) world $(c.world) ",
                    "($(kind(string(c.where_), c.copy, c.world))): compiled $(c.compiled) fresh $(c.fresh) expected $(c.expected)")
            println(det, "    worlds ", join(Int.(info.worlds), ", "), "; the pair holds ", join([s[1] for s in info.states], ", "))
            try
                ci_report(det, info.M, c.form, c.question, c.copy, info.worlds[c.world+1], args)
            catch e
                println(det, "    (no report: ", sprint(showerror, e)[1:min(end, 120)], ")")
            end
            if !isempty(PROBES)
                write(joinpath(PROBES, "$(c.question)-$(c.shape)-$(c.seq).jl"), probe_src(c))
            end
            flush(det)
        end
    end
    for i in from:length(cs)
        sh, q = cs[i]
        println("CASE ", i, " ", sh.name, "/", q.name); flush(stdout)
        try
            run_case(sh, q; declare, record)
        catch e
            println(det, "!! case error $(sh.name)/$(q.name): ", replace(sprint(showerror, e)[1:min(end, 300)], '\n' => ' '))
        end
        flush(tsv); flush(det)
    end
    close(tsv); close(det)
end

function parent()
    commit = Base.GIT_VERSION_INFO.commit_short
    println("set_folds: Julia ", VERSION, " ", commit, ", mode ", MODE, ", jl_delete_membership ",
            HAS_DELETE ? "present" : "absent")
    cs = cases()
    for s in SKIPPED; println("skipped: ", s); end
    println("cases: ", length(cs), " (", length(unique(c[1].name for c in cs)), " shapes, ",
            length(unique(c[2].name for c in cs)), " sequences); questions: ", join(QSEL, " "))
    isempty(PROBES) || mkpath(PROBES)
    out = tempname()
    passthrough = filter(a -> !startswith(a, "--worker") && !startswith(a, "--from") && !startswith(a, "--sample") &&
                         !startswith(a, "--seed"), ARGS)
    crashes = Tuple{String,String}[]
    t0 = time()
    from = 1
    names = ["$(c[1].name)/$(c[2].name)" for c in cs]
    # a sample is passed on as the names it drew
    onlyarg = haskey(ARGS_D, "sample") ? ["--only=^(" * join(map(n -> replace(n, "/" => "\\/"), names), "|") * ")\$"] : String[]
    passthrough = vcat(filter(a -> !startswith(a, "--only"), passthrough), isempty(onlyarg) ? filter(a -> startswith(a, "--only"), ARGS) : onlyarg)
    while from <= length(cs)
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(@__FILE__) --worker=$out --from=$from $passthrough`
        last = 0
        errio = IOBuffer()
        p = run(pipeline(ignorestatus(cmd); stdout = (r = Pipe()), stderr = errio); wait = false)
        close(r.in)
        for l in eachline(r)
            startswith(l, "CASE ") && (last = parse(Int, split(l)[2]))
        end
        wait(p)
        if success(p)
            break
        end
        msg = String(take!(errio))
        lines = filter(l -> occursin(r"Unreachable|signal|ERROR|error", l), split(msg, '\n'))
        push!(crashes, (last == 0 ? "?" : names[last], join(first(lines, 2), " | ")))
        from = last == 0 ? length(cs) + 1 : last + 1
    end
    dt = time() - t0
    rows = isfile(out * ".tsv") ? [split(l, '\t') for l in eachline(out * ".tsv")] : Vector{SubString{String}}[]
    details = isfile(out * ".details") ? read(out * ".details", String) : ""
    report(rows, details, crashes, length(cs), dt)
end

function report(rows, details, crashes, ncases, dt)
    F = (case = 1, shape = 2, seq = 3, question = 4, form = 5, copy = 6, world = 7, vi = 8, where_ = 9,
         compiled = 10, fresh = 11, expected = 12, dynamic = 13, mm = 14, db = 15, ob = 16)
    mism = filter(r -> r[F.mm] == "1", rows)
    dyn = filter(r -> r[F.db] == "1", rows)
    orac = filter(r -> r[F.ob] == "1", rows)
    kindof(r) = kind(r[F.where_], parse(Int, r[F.copy]), parse(Int, r[F.world]))
    function groups(v, keyf)
        d = Dict{Any,Vector{Any}}()
        for r in v; push!(get!(d, keyf(r), Any[]), r); end
        sort!(collect(d); by = p -> (-length(p[2]), string(p[1])))
    end
    println("ran in ", round(dt; digits = 1), " s: ", length(rows), " checks")
    for (n, e) in crashes; println("crash: ", n, ": ", e); end
    cerr = filter(l -> startswith(l, "!! "), split(details, '\n'))
    for l in cerr; println(l); end
    println("\n== compiled against fresh: ", length(mism), " mismatches (question, shape, sequence: count, forms, kinds)")
    for (k, v) in groups(mism, r -> (r[F.question], r[F.shape], r[F.seq]))
        kinds = join(["$(a)×$(length(b))" for (a, b) in groups(v, kindof)], " ")
        forms = join(sort(unique(r[F.form] for r in v)), ",")
        ans = join(sort(unique("$(r[F.compiled])/$(r[F.fresh])" for r in v)), " ")
        println("  ", rpad(k[1], 8), rpad(k[2], 18), rpad(k[3], 19), lpad(length(v), 4), "  forms ", rpad(forms, 10), " ", kinds, "  compiled/fresh ", ans)
    end
    println("\n== by question: ", join(["$(a) $(length(b))" for (a, b) in groups(mism, r -> r[F.question])], ", "))
    println("== by shape: ", join(["$(a) $(length(b))" for (a, b) in groups(mism, r -> r[F.shape])], ", "))
    println("== by sequence: ", join(["$(a) $(length(b))" for (a, b) in groups(mism, r -> r[F.seq])], ", "))
    println("== by kind: ", join(["$(a) $(length(b))" for (a, b) in groups(mism, kindof)], ", "))
    println("== by form: ", join(["$(a) $(length(b))" for (a, b) in groups(mism, r -> r[F.form])], ", "))
    println("\n== the runtime's dynamic answer (its caches) against fresh: ", length(dyn))
    for (k, v) in groups(dyn, r -> (r[F.question], r[F.shape], r[F.seq]))
        println("  ", k, " ", length(v), "  e.g. world $(v[1][F.world]): $(v[1][F.dynamic]) against $(v[1][F.fresh])")
    end
    println("\n== fresh against the shape's expected answer: ", length(orac))
    for (k, v) in groups(orac, r -> (r[F.question], r[F.shape], r[F.seq]))
        println("  ", k, " ", length(v), "  e.g. world $(v[1][F.world]): fresh $(v[1][F.fresh]) expected $(v[1][F.expected])")
    end
    if SHOW > 0 && !isempty(details)
        println("\n== the first mismatch of each group (at most $SHOW), with the code's worlds and edges")
        blocks = split(details, "\n-- ")
        for (i, b) in enumerate(blocks)
            i > SHOW + 1 && break
            isempty(strip(b)) && continue
            println(startswith(b, "-- ") ? b : "-- " * b)
        end
    end
    nq = length(unique((r[F.question], r[F.shape], r[F.seq]) for r in mism))
    println("\nset_folds: $ncases cases, $(length(rows)) checks, $(length(mism)) mismatches in $nq groups, ",
            "$(length(crashes)) crashes, $(length(cerr)) case errors, $(length(dyn)) dynamic, $(length(orac)) fresh-vs-expected, $(round(dt; digits=1)) s")
end

if haskey(ARGS_D, "worker")
    worker(ARGS_D["worker"], parse(Int, get(ARGS_D, "from", "1")))
else
    parent()
end
