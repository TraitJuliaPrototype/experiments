# Gate (compiler §4.8; E-545, C-170): an opaque closure's call whose signature names a set, at an argument of a type
# that could join it, is not inferred to throw by an empty intersection: the caller compiled before `S` joins `X` runs
# the closure once the membership holds, and taken back raises the closure's `TypeError` again. A candidate for
# `gates/`; fails on `next` 0bbd759c13 (the caller runs into `unreachable`: it is asked in a child process).
#     julia --project=experiments/implementation n58_opaque_closure_set.jl
code = raw"""
using Traits
@trait X58
struct S58 end
f() = (oc = Base.Experimental.@opaque (x::X58) -> :called; oc(S58()))
r(g) = try g() catch e; Symbol(nameof(typeof(e))) end
a = r(f)
Traits.declare_membership(S58, X58, @__MODULE__)
b = r(f)
ccall(:jl_delete_membership, Cvoid, (Any, Any, Any), S58, X58, @__MODULE__)
c = r(f)
println("ANSWERS ", a, " ", b, " ", c)
"""
out = IOBuffer()
p = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $code`); stdout = out, stderr = out))
s = String(take!(out))
m = match(r"ANSWERS (\S+) (\S+) (\S+)", s)
@assert success(p) && m !== nothing "the caller compiled before the membership: $(first(s, 600))"
@assert m.captures[1] == "TypeError" && m.captures[2] == "called" && m.captures[3] == "TypeError" "answers $(m.captures)"
println("n58_opaque_closure_set: OK")
