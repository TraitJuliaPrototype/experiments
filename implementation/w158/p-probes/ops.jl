# C-158, seventh part: which operations' declared results the members' check does not reach (traits §5.10), and
# whether a result is trusted there (compiler §7.1, §7.4). Each case: a trait whose operation declares a result, a
# member whose own code returns a value outside it, and the operation passed on to code compiled for the member
# (`apply1(op, v[1])`, the value known by the trait); then `r isa <declared>`. Verdicts:
#   refused   the member, or the method, was refused where it was declared (ImplementError at the declaration)
#   raised    the member's check raised at its first use (ImplementError when the program ran)
#   checked   the check after the call raised (TypeError, typeassert's)
#   own       the member's own result reached the caller, typed as it is ("no": nothing narrower was trusted)
#   HOLE      `r isa <declared>` answered yes for a value outside it: a type trusted that the value does not have
# `julia --project=<TraitWorld> p-probes/ops.jl`; `ONLY=<case>`; `PATCH=<file>` includes a file first. Exits 1 on a hole.
haskey(ENV, "PATCH") && include(ENV["PATCH"])
using TraitWorld

apply1(f, x) = f(x)
apply2(f, x, y) = f(x, y)
apply3(f, x, y, z) = f(x, y, z)
results = Pair{String,String}[]
note(name, v) = (push!(results, name => v); println(rpad(name, 44), v))
function run_case(name, thunk, declared)
    r = try
        Base.invokelatest(thunk)
    catch e
        e isa TraitWorld.ImplementError && return note(name, "raised (" * first(sprint(showerror, e), 160) * ")")
        e isa TypeError && e.func in (:typeassert, :Callable) && return note(name, "checked ($(e.func), expected $(e.expected), got $(repr(e.got)))")
        return note(name, "error " * first(sprint(showerror, e), 200))
    end
    r == "no" && return note(name, "own")
    return note(name, "HOLE (`isa $declared` said yes for a value outside it)")
end
# a declaration that may be refused: evaluated at top level, the verdict "refused" where it raises
function declare(name, ex)
    try
        Core.eval(Main, ex)
        return true
    catch e
        e = e isa LoadError ? e.error : e
        note(name, "refused (" * first(replace(sprint(showerror, e), '\n' => ' '), 200) * ")")
        return false
    end
end
only = get(ENV, "ONLY", "")
want(c) = isempty(only) || only == c

# 1. a further argument declared at a type that is not concrete (the control: marked, the sixth part)
if want("further")
    @eval begin
        @trait P1 begin
            p1op(x::P1, s)::Float64
        end
        struct P1A end
        p1op(::P1A, s) = 1
        @implement P1 P1A
    end
    run_case("further argument abstract", () -> (r = apply2(p1op, P1[P1A()][1], nothing); r isa Float64 ? "yes" : "no"), Float64)
end

# 2. a second value of the set
if want("second")
    @eval begin
        @trait P2 begin
            p2op(x::P2, y::P2)::Float64
        end
        struct P2A end
        p2op(::P2A, ::P2) = 1
        @implement P2 P2A
    end
    run_case("a second value of the set", () -> (v = P2[P2A()]; r = apply2(p2op, v[1], v[1]); r isa Float64 ? "yes" : "no"), Float64)
end

# 3. an operation's own `where` variable: checked at its bound (`Any`), at the call fixed by the argument
if want("where")
    @eval begin
        @trait P3 begin
            p3op(x::P3, d::D)::Union{Float64, D} where {D}
        end
        struct P3A end
        p3op(::P3A, d) = "s"
        @implement P3 P3A
    end
    run_case("an operation's own where variable", () -> (r = apply2(p3op, P3[P3A()][1], 1); r isa Union{Float64, Int} ? "yes" : "no"), Union{Float64, Int})
end

# 3b. a where variable bounded by a concrete type's supertype: the bound abstract, the call's type concrete
if want("wherebound")
    @eval begin
        @trait P3b begin
            p3bop(x::P3b, d::D)::D where {D <: Real}
        end
        struct P3bA end
        p3bop(::P3bA, d) = "s"
        @implement P3b P3bA
    end
    run_case("a where variable with a bound", () -> (r = apply2(p3bop, P3b[P3bA()][1], 1); r isa Int ? "yes" : "no"), Int)
end

# 4. a default's method (no method of the member's own): its declared result on the method converts and asserts
if want("default")
    @eval begin
        @trait P4 begin
            p4op(x::P4)::Float64 = 1
        end
        struct P4A end
        @implement P4 P4A
    end
    run_case("a default's method", () -> (r = apply1(p4op, P4[P4A()][1]); r isa Float64 ? (r === 1.0 ? "no" : "yes") : "no"), Float64)
end

# 5. a member that forwards (`by`) to a field of a concrete member: the field's method checked at its membership
if want("by")
    @eval begin
        @trait P5 begin
            p5op(x::P5)::Float64
        end
        struct P5In end
        p5op(::P5In) = 2.0
        @implement P5 P5In
        struct P5A; inner::P5In; end
        @implement P5 P5A by inner
    end
    run_case("forwarding to a concrete member (control)", () -> (r = apply1(p5op, P5[P5A(P5In())][1]); r isa Float64 && r === 2.0 ? "no" : "yes"), Float64)
end

# 5b. a member that forwards to a field typed by an abstract type that is a member (checked per type at first use)
if want("byabstract")
    @eval begin
        @trait P5b begin
            p5bop(x::P5b)::Float64
        end
        abstract type P5bAbs end
        struct P5bR <: P5bAbs end
        p5bop(::P5bR) = 1
        @implement P5b P5bAbs
        struct P5bA; inner::P5bAbs; end
    end
    if declare("forwarding to an abstract field", :(@implement P5b P5bA by inner))
        run_case("forwarding to an abstract field", () -> (r = apply1(p5bop, P5b[P5bA(P5bR())][1]); r isa Float64 ? "yes" : "no"), Float64)
    end
end

# 6. a member of a family, not yet used through the trait
if want("family")
    @eval begin
        @trait P6 begin
            p6op(x::P6)::Float64
        end
        struct P6F{T} end
        p6op(::P6F{T}) where {T} = 1
        @implement P6 P6F{T} where {T}
    end
    run_case("a family's member, first use by a pass-on", () -> (r = apply1(p6op, P6[P6F{Int}()][1]); r isa Float64 ? "yes" : "no"), Float64)
end

# 6b. a member of an abstract type
if want("abstract")
    @eval begin
        @trait P6b begin
            p6bop(x::P6b)::Float64
        end
        abstract type P6bAbs end
        struct P6bR <: P6bAbs end
        p6bop(::P6bR) = 1
        @implement P6b P6bAbs
    end
    run_case("an abstract type's member, first use by a pass-on", () -> (r = apply1(p6bop, P6b[P6bR()][1]); r isa Float64 ? "yes" : "no"), Float64)
end

# 7. a method of the operation defined after the membership was checked (traits §5.10: refused where it widens)
if want("redefine")
    @eval begin
        @trait P7 begin
            p7op(x::P7)::Float64
        end
        struct P7A end
        p7op(::P7A) = 2.0
        @implement P7 P7A
    end
    if declare("a later method of the operation", :(p7op(::P7A) = 1))
        run_case("a later method of the operation", () -> (r = apply1(p7op, P7[P7A()][1]); r isa Float64 ? "yes" : "no"), Float64)
    end
end

# 7b. a later method below the operation's body (T-129: judged by one intersection per kept call)
if want("below")
    @eval begin
        @trait P7b begin
            p7bop(x::P7b)::Float64
        end
        struct P7bA end
        p7bhelp(x) = 2.0
        p7bop(a::P7bA) = p7bhelp(a)
        @implement P7b P7bA
    end
    if declare("a later method below the body", :(p7bhelp(::P7bA) = 1))
        run_case("a later method below the body", () -> (r = apply1(p7bop, P7b[P7bA()][1]); r isa Float64 ? "yes" : "no"), Float64)
    end
end

# 8. a pirate's method below the body (a module that owns neither the function nor the type)
if want("pirate")
    Core.eval(Main, Expr(:toplevel, :(module P8Lib; h(x) = 2.0; end)))
    @eval begin
        @trait P8 begin
            p8op(x::P8)::Float64
        end
        struct P8A; x::Int; end
        p8op(a::P8A) = P8Lib.h(a.x)
        @implement P8 P8A
    end
    if declare("a pirate's method below the body", Expr(:toplevel, :(module P8Pirate; import ..P8Lib; P8Lib.h(::Int) = 1; end)))
        run_case("a pirate's method below the body", () -> (r = apply1(p8op, P8[P8A(1)][1]); r isa Float64 ? "yes" : "no"), Float64)
    end
end

# 9. a member's method at a kept form: the wrapper of a member, a method more specific than the forwarding one
if want("kept")
    @eval begin
        @trait P9 begin
            p9op(x::P9)::Float64
        end
        struct P9A end
        p9op(::P9A) = 2.0
        @implement P9 P9A
    end
    if declare("a method at the member's wrapper", :(p9op(::Compiled{P9A}) = 1))
        run_case("a method at the member's wrapper", () -> (r = apply1(p9op, P9[compiled_for(P9A())][1]); r isa Float64 ? "yes" : "no"), Float64)
    end
end

# 10. a declared field of a family's member not yet used: the field's check at the member's first use
if want("field")
    @eval begin
        @trait P10 begin
            @const p10f::Float64
        end
        struct P10F{T}; p10f::T; end
        @implement P10 P10F{T} where {T}
        getf(x) = x.p10f
    end
    run_case("a declared field, a family's member", () -> (r = apply1(getf, P10[P10F{Int}(1)][1]); r isa Float64 ? "yes" : "no"), Float64)
end

# 11. a member declared in a package image, and a method below its body already in the session when it loads
# (`p-probes/imgpkg/`: PImgQ's `h`, PImg's trait and member; the session's method `PImgQ.h(::Int)` comes first)
if want("image")
    # an implicit environment of the two packages and the library the session loaded
    dir = mktempdir()
    for (n, p) in (("PImgQ", joinpath(@__DIR__, "imgpkg", "PImgQ")), ("PImg", joinpath(@__DIR__, "imgpkg", "PImg")),
                   ("TraitWorld", dirname(dirname(pathof(TraitWorld)))))
        symlink(p, joinpath(dir, n))
    end
    push!(LOAD_PATH, dir)
    # the image written by a process of its own, before this session's method exists
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e "push!(LOAD_PATH, \"$dir\"); using PImg"`)
    @eval using PImgQ
    @eval PImgQ.h(::Int) = 1
    @eval using PImg
    run_case("an image's member, a method already in the session", () -> (r = apply1(PImg.iop, PImg.IX[PImg.IA(1)][1]); r isa Float64 ? "yes" : "no"), Float64)
end

nh = count(p -> startswith(p.second, "HOLE"), results)
println("\njulia ", Base.GIT_VERSION_INFO.commit_short, ": ", nh, " holes in ", length(results), " cases")
exit(nh > 0 ? 1 : 0)
