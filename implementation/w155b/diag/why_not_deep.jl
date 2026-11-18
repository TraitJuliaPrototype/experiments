# W-155b (open issue 211): why each instance is outside the deep class, by the first edge that keeps it out.
# The pattern (E-417's faults, and this one): an edge kind the class allows (compiler §3.2: a binding, an
# absence edge, a positive membership, an `invoke` edge) that the predicate tests as a callee or a dispatch
# edge. The tool reads every valid instance of Julia's own owner in the session, replays the predicate with
# a reason per edge, and counts the reasons; a reason "membership" above 0 is an instance of the pattern.
#     julia --project=<env> why_not_deep.jl [csv] <package>...
const ARGV = copy(ARGS)
const csv = !isempty(ARGV) && endswith(ARGV[1], ".csv") ? popfirst!(ARGV) : nothing
for p in ARGV; Core.eval(Main, Meta.parse("using $p")); end
if csv !== nothing
    w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                     g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
    Base.invokelatest(w)
end
const C = Base.Compiler
isimpl(@nospecialize(sig)) = (b = Base.unwrap_unionall(sig); b isa DataType && length(b.parameters) == 3 && b.parameters[1] === typeof(Core.implements))
ismembmi(mi::Core.MethodInstance) = (m = mi.def; m isa Method && isimpl(m.sig))
# the predicate replayed with a reason, a positive membership's edge allowed (compiler §3.2, open issue 211)
function reason(ci::Core.CodeInstance)
    mi = C.get_ci_mi(ci)
    for e in ci.edges
        if e isa Core.CodeInstance
            e === ci && continue
            (e.flags & 0x10) == 0 && return "a callee's CodeInstance without the bit"
        elseif e isa Core.MethodInstance
            (e === mi || ismembmi(e)) && continue
            return "a callee named by its MethodInstance alone"
        end
    end
    for (invokesig, item) in C.ForwardToBackedgeIterator(ci.edges)
        if item isa Core.MethodTable
            (C.is_fact_sig(invokesig) || isimpl(invokesig)) || return "a call that found no method, at a signature that is no fact"
        elseif item isa Core.MethodInstance
            ismembmi(item) && continue
            (invokesig === nothing || invokesig isa C.CallSigBackedge) || continue
            C.is_fact_sig(invokesig isa C.CallSigBackedge ? invokesig.sig : item.specTypes) || return "a dispatch edge at a signature that is no fact"
        end
    end
    # nothing keeps it out by the predicate: a positive membership's edge, if it holds one, is what the
    # build's predicate refused (the pattern); else an inference cycle decided as one
    any(e -> e isa Core.MethodInstance && ismembmi(e), ci.edges) &&
        return "membership: only a positive membership's edge keeps it out (the pattern)"
    return "none found (an inference cycle decided as one, or a callee's bit set later)"
end
counts = Dict{String,Int}(); ex = Dict{String,Vector{String}}(); nall = 0; ndeep = 0; nmemb = 0
Base.visit(Core.methodtable) do m
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && isdefined(mi, :cache) || continue
        ci = mi.cache
        while true
            if ci.max_world == typemax(UInt) && ci.owner === nothing && isdefined(ci, :edges)
                global nall += 1
                if (ci.flags & 0x10) != 0
                    global ndeep += 1
                else
                    r = reason(ci)
                    counts[r] = get(counts, r, 0) + 1
                    v = get!(ex, r, String[]); length(v) < 5 && push!(v, first(string(mi.specTypes), 150))
                end
                any(e -> e isa Core.MethodInstance && ismembmi(e), ci.edges) && (global nmemb += 1)
            end
            isdefined(ci, :next) || break; ci = ci.next
        end
    end
end
println("# why_not_deep | ", join(ARGV, " "), " | Julia ", Base.GIT_VERSION_INFO.commit_short, " | valid instances ", nall,
        ", with the bit ", ndeep, " | instances that hold a positive membership's edge ", nmemb)
for (k, v) in sort(collect(counts); by = last, rev = true)
    println(lpad(v, 8), "  ", k)
    for e in ex[k]; println("            ", e); end
end
