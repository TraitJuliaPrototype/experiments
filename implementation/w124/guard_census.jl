# W-124's counter, first form (E-319): the guarded calls a session holds, read from the CodeInstances' edges.
# A guarded call (compiler §5.6) records an edge to a `Core.MembershipCell(member, set)`; this counts, over
# every live CodeInstance after the session's script ran, the instances with such edges, by the cell, by the
# caller's module, from an image or compiled in the session, and whether the cell is open (its guard then
# takes the dynamic call). "(d) final": the cell's member type and set both belong to packages that have
# finished loading (not Main), so finality by ownership (open issue 158 (d)) would fold the negative.
#   SCRIPT=<script> [ARGS for it in CENSUS_ARGS, `;`-separated] julia --project=<env> guard_census.jl
if haskey(ENV, "SCRIPT")
    empty!(ARGS); haskey(ENV, "CENSUS_ARGS") && append!(ARGS, split(ENV["CENSUS_ARGS"], ';'))
    t0 = time(); include(ENV["SCRIPT"]); println("script: ", round(time() - t0, digits = 3), " s")
end
const CellT = Core.MembershipCell
typemod(@nospecialize(t)) = t isa Core.TypeName ? t.module : (u = Base.unwrap_unionall(t); u isa DataType ? u.name.module : nothing)
ispkgmod(m) = m isa Module && m !== Main && Base.moduleroot(m) !== Main
total_ci = Ref(0); guarded = Ref(0); guarded_img = Ref(0); open_guards = Ref(0)
bycell = Dict{Any, Vector{Int}}()        # (member, set) => [CIs, from an image, open]
bymod = Dict{Module, Int}()
examples = Dict{Any, Vector{String}}()
mt = isdefined(Core, :methodtable) ? Core.methodtable : Core.GlobalMethods
Base.visit(mt) do m
    m isa Method || return
    for mi in Base.specializations(m)
        ci = isdefined(mi, :cache) ? mi.cache : nothing
        while ci !== nothing
            if ci.owner === nothing && ci.max_world == typemax(UInt)
                total_ci[] += 1
                cells = isdefined(ci, :edges) ? [e for e in ci.edges if e isa CellT] : CellT[]
                if !isempty(cells)
                    guarded[] += 1
                    img = (getfield(ci, :flags, :monotonic)::UInt8 & 0x04) != 0
                    img && (guarded_img[] += 1)
                    bymod[m.module] = get(bymod, m.module, 0) + 1
                    for c in unique(cells)
                        k = (getfield(c, :member), getfield(c, :set))
                        v = get!(() -> [0, 0, 0], bycell, k)
                        v[1] += 1; img && (v[2] += 1)
                        isopen = getfield(c, :min_world, :monotonic) != typemax(UInt64)
                        isopen && (v[3] += 1; open_guards[] += 1)
                        ex = get!(() -> String[], examples, k)
                        length(ex) < 3 && push!(ex, string(mi.specTypes)[1:min(end, 160)])
                    end
                end
            end
            ci = isdefined(ci, :next) ? ci.next : nothing
        end
    end
end
println("live CodeInstances: ", total_ci[], "; with a guard: ", guarded[], " (from an image ", guarded_img[], "); guards at an open cell: ", open_guards[])
println("== by cell (member, set): instances, from an image, open; (d) final")
for (k, v) in first(sort(collect(bycell); by = x -> -x[2][1]), 40)
    fin = ispkgmod(typemod(k[1])) && ispkgmod(typemod(k[2]))
    println("  ", lpad(v[1], 5), " ", lpad(v[2], 5), " ", lpad(v[3], 3), "  ", fin ? "final " : "      ", k[1], " at ", k[2])
    for e in examples[k]; println("          ", e); end
end
println("== by the caller's module")
for (m, n) in first(sort(collect(bymod); by = x -> -x[2]), 20); println("  ", lpad(n, 5), "  ", m); end
