# Gate (W-99, the audit's A7; compiler §5.4): the ambiguity report at a membership asks at the
# methods' own arity. A pair of two-argument methods whose other arguments never meet warns zero
# times (the report used to ask with one argument, get no match, and call that an ambiguity); a
# pair that a call reaches warns once and names the signature that would resolve it, at All{XE, YE}.
include("util.jl")

const JULIA = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`

body = """
    using Traits
    @trait XE
    @trait YE
    f2(::XE, ::Int) = :x
    f2(::YE, ::String) = :y              # no call reaches both: not ambiguous
    h2(::XE, ::Int) = :x
    h2(::YE, ::Integer) = :y             # h2(ME(), 1) reaches both: ambiguous
    struct ME end
    @implement XE ME
    @implement YE ME
    println("CHILD_F2 ", f2(ME(), 1), " ", f2(ME(), "a"))
    res = try
        h2(ME(), 1); "nothrow"
    catch e
        (e isa MethodError || occursin("ambiguous", sprint(showerror, e))) ? "raised" : "wrong"
    end
    println("CHILD_H2 ", res)
    println("CHILD_DONE")
"""

function child(body)
    sp, op, ep = tempname(), tempname(), tempname()
    write(sp, body)
    open(op, "w") do of
        open(ep, "w") do ef
            run(pipeline(`$JULIA $sp`, stdout=of, stderr=ef))
        end
    end
    out, err = read(op, String), read(ep, String)
    rm.([sp, op, ep], force=true)
    return out, err
end

out, err = child(body)
@assert occursin("CHILD_DONE", out) "child completed: $out $err"
@assert occursin("CHILD_F2 x y", out) "f2 dispatches by its second argument: $out"
@assert occursin("CHILD_H2 raised", out) "h2 is ambiguous at ME: $out"
warns = [m.match for m in eachmatch(r"WARNING: method [^\n]*", err)]
@assert !any(w -> occursin("method f2 ", w), warns) "no warning for f2, whose methods no call reaches together: $warns"
@assert count(w -> occursin("method h2 ", w), warns) == 1 "one warning for h2: $warns"
# the joint method: the two signatures' intersection, the sets meeting as All{XE, YE} (W-107)
@assert any(w -> occursin("method h2 ", w) && occursin("would resolve it", w) &&
                 occursin(r"All\{Main\.[XY]E, Main\.[XY]E\}, Int64", w), warns) "the warning names the joint signature: $warns"

println("m2_ambiguity_arity: OK")
