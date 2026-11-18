# Gate (compiler §5.4; traits §6.3, §12.3; E-346): the report names the ambiguities a membership creates.
# TD in YD and ZD, with kD at both: the ZD membership creates the ambiguity and warns once. A later
# membership of TD in XD0, a set without kD, creates none: no warning, and under strict mode it is
# accepted. Its redeclaration under strict mode is accepted too.
include("util.jl")

const JULIA = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project())`

body = """
    using Traits
    @trait XD0
    @trait YD
    @trait ZD
    kD(::YD) = :y
    kD(::ZD) = :z
    struct TD end
    @implement YD TD
    @implement ZD TD
    @implement XD0 TD
    ccall(:jl_set_strict_memberships, Cint, (Cint,), 1)
    @trait XD1
    r = try
        @implement XD1 TD
        "accepted"
    catch e
        "refused: " * sprint(showerror, e)
    end
    println("CHILD_STRICT ", r, " ", Base.invokelatest(() -> TD <: XD1))
    r2 = try
        @implement ZD TD
        "accepted"
    catch e
        "refused"
    end
    println("CHILD_REDECLARE ", r2)
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

out, err = child(body)
println(out); println(err)
@assert occursin("CHILD_DONE", out) "child completed: $out $err"
# the runtime's warning is unbuffered, the script's markers are not: count the warnings in all
@assert length(collect(eachmatch(r" is ambiguous for ", err))) == 1 "one warning, at ZD: the XD0 membership and the redeclaration create nothing"
@assert occursin("CHILD_STRICT accepted true", out) "under strict mode an unrelated membership is accepted"
@assert occursin("CHILD_REDECLARE accepted", out) "a redeclaration creates nothing"
println("m2_ambiguity_predates: OK")
