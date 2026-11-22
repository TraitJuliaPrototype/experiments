# W-143d (E-540): the faults "a callee named by its MethodInstance alone" (the census's :mi), by pattern: the callee's
# method has `@nospecialize` arguments (the compiled instance is wider than the one inference used) or not; whether the
# instance has code with the G2 bit now; the cones of the culprits holding such a fault.
include(joinpath(@__DIR__, "..", "census_lib.jl"))
const csv = ARGS[1]
S = census_session(csv)
cnt = Dict{Tuple{Bool,Bool,Symbol},Vector{Int}}()
ex = Dict{Tuple{Bool,Bool,Symbol},Vector{String}}()
for (y, k) in S.culprit, f in get(S.fcache, y, Fault[])
    f.kind === :mi || continue
    mi = f.sig::Core.MethodInstance
    m = mi.def; nospec = m isa Method && m.nospecialize != 0
    withbit = any(bit, micode(mi))
    q = (nospec, withbit, m isa Method ? m.name : :none)
    push!(get!(cnt, q, Int[]), get(S.incone, y, 0))
    v = get!(ex, q, String[]); length(v) < 2 && push!(v, string(first(string(y.def.specTypes), 90), " -> ", first(string(mi.specTypes), 80)))
end
println("callee's method @nospecialize | callee has code with the bit now | callee | faults | most cones")
for (q, v) in sort(collect(cnt); by = x -> -maximum(x[2]))
    println(rpad(q[1], 6), rpad(q[2], 6), rpad(q[3], 28), lpad(length(v), 5), lpad(maximum(v), 7), "   e.g. ", ex[q][1])
end
