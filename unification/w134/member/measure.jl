# E-360: what a member package's load brings.   julia --project=../env_demo measure.jl <package> <library>...
# After the libraries are loaded: the valid instances the package's load adds, by the module of their method and
# facts or plain; how many of them do not name one of the package's exports (the member) in their signature; the bytes of its image files.
const FACTS = 0x20
const name = ARGS[1]
for l in ARGS[2:end]; Core.eval(Main, Meta.parse("using $l")); end
function tally()
    res = Tuple{Symbol,Core.CodeInstance}[]
    Base.visit(Core.methodtable) do m
        r = nameof(Base.moduleroot(m.module))
        for mi in Base.specializations(m)
            mi isa Core.MethodInstance || continue
            isdefined(mi, :cache) || continue
            ci = mi.cache
            while true
                ci.max_world == typemax(UInt) && ci.owner === nothing && push!(res, (r, ci))
                isdefined(ci, :next) || break; ci = ci.next
            end
        end
    end
    return res
end
before = tally()
t = @elapsed Core.eval(Main, Meta.parse("using $name"))
after = tally(); seen = IdSet{Any}(ci for (_, ci) in before)
new = [(r, ci) for (r, ci) in after if !(ci in seen)]
ended = count(x -> x[2].max_world != typemax(UInt), before)
by = Dict{String,Int}()
for (r, ci) in new; k = string(r, (ci.flags & FACTS) != 0 ? " facts" : " plain"); by[k] = get(by, k, 0) + 1; end
m = getfield(Main, Symbol(name)); own = [string(n) for n in names(m) if n !== Symbol(name)]
other = [(r, ci) for (r, ci) in new if r !== Symbol(name) && !any(n -> occursin(n, string(ci.def.specTypes)), own)]
ji = Base.find_all_in_cache_path(Base.PkgId(m))
ji = ji[argmax(mtime.(ji))]; so = Base.ocachefile_from_cachefile(ji)
println(rpad(name, 8), " load ", round(1000t; digits = 1), " ms | instances ", length(new), " (facts ", count(x -> (x[2].flags & FACTS) != 0, new),
        "; not naming the member ", length(other), "); ended ", ended, " | image ", filesize(ji), " + ", isfile(so) ? filesize(so) : 0, " bytes | ",
        join(["$k $v" for (k, v) in sort(collect(by); by = last, rev = true)], ", "))
for (r, ci) in other[1:min(end, parse(Int, get(ENV, "SHOW", "0")))]; println("    other: ", ci.def.specTypes); end
