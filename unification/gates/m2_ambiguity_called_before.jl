# Gate (compiler §5.4, §5.5; traits §6.3, §12.3; E-343): a member called before its second membership.
# `g() = f(MC())` is called once, so dispatch has cached `f(::YC)` at `MC`; then `@implement XC MC` makes
# `f(::XC)` and `f(::YC)` ambiguous for `MC`. The membership's walk lowers the cache entry, so the dynamic
# call and the compiled one raise, and the report warns. Under strict mode the same membership is
# refused, and `MC` stays a member of `YC` alone.
include("util.jl")

const JULIA = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`

body(strict) = """
    using Traits
    ccall(:jl_set_strict_memberships, Cint, (Cint,), $(strict ? 1 : 0))
    @trait XC
    @trait YC
    f(::XC) = :x
    f(::YC) = :y
    struct MC end
    @implement YC MC
    g() = f(MC())
    println("CHILD_BEFORE ", g(), " ", f(MC()))
    declared = try
        @implement XC MC
        "declared"
    catch e
        "refused: " * replace(sprint(showerror, e), "\\n" => " | ")
    end
    println("CHILD_DECL ", declared)
    res(h) = try
        string(Base.invokelatest(h))
    catch e
        e isa MethodError ? "raised" : "wrong " * string(typeof(e))
    end
    println("CHILD_DYNAMIC ", res(() -> f(MC())))
    println("CHILD_COMPILED ", res(g))
    println("CHILD_MEMBER ", Base.invokelatest(() -> MC <: XC), " ", Base.invokelatest(() -> MC <: YC))
    println("CHILD_DONE")
"""

function child(body)
    sp, op, ep = tempname(), tempname(), tempname()
    write(sp, body)
    open(op, "w") do of
        open(ep, "w") do ef
            run(pipeline(ignorestatus(`$JULIA $sp`), stdout=of, stderr=ef))
        end
    end
    out, err = read(op, String), read(ep, String)
    rm.([sp, op, ep], force=true)
    return out, err
end

out, err = child(body(false))
println(out)
@assert occursin("CHILD_DONE", out) "child completed: $out $err"
@assert occursin("CHILD_BEFORE y y", out)
@assert occursin("CHILD_DECL declared", out)
@assert occursin(" is ambiguous for ", err) "the report warns: $err"
@assert occursin("CHILD_DYNAMIC raised", out) "the dynamic call raises after the membership"
@assert occursin("CHILD_COMPILED raised", out) "the compiled call raises after the membership"

out2, err2 = child(body(true))
println(out2)
@assert occursin("CHILD_DONE", out2) "strict child completed: $out2 $err2"
@assert occursin("CHILD_DECL refused: ", out2) && occursin("ambiguous", out2) "strict mode refuses"
@assert occursin("CHILD_DYNAMIC y", out2) && occursin("CHILD_COMPILED y", out2) "the refused membership changes nothing"
@assert occursin("CHILD_MEMBER false true", out2)
@assert !occursin(" is ambiguous for ", err2) "no warning for a refused membership"

println("m2_ambiguity_called_before: OK")
