# W-151's count of the annotations library code writes to choose how a trait's value is compiled (the plan's stage 1
# gate: "the annotations in library code (keep, casts, Erased, @nospecialize at a trait argument), counted before and
# after"). Read from git at a revision, so the baseline (the tag `prototype-2026-11`) and the head are counted alike.
# Comments and docstrings are left out. Per kind:
#   keep          a call `keep(…)` (traits §7.8)
#   cast          a call `compiled_for(…)` or `with_dynamic(…)` (the cast; under D-1 `compiled_for` is a value)
#   Erased        the ODE port's `Erased` (a function kept `Dynamic` whatever the call)
#   kept_call     `Kept{…}`, `kept_call(…)` (storage with an attribute)
#   nospec_trait  `@nospecialize(x::T)` where `T` names a trait (one of `@trait`'s names in the sources read,
#                 BaseTraits', `Callable`, `All`)
#   box           a box written by hand, `Dynamic{…}(…)`
#   erasing       `@erasing` (W-151: stands for what lowering would make implicit)
#   unwrap        a call `unwrap(…)` (the barrier back to code per type)
#     julia annotations.jl <repo> <rev> <dir>...
const KINDS = (:keep, :cast, :Erased, :kept_call, :nospec_trait, :box, :erasing, :unwrap)
repo, rev = ARGS[1], ARGS[2]
dirs = ARGS[3:end]
files = String[]
for d in dirs
    out = read(`git -C $repo ls-tree -r --name-only $rev -- $d`, String)
    append!(files, filter(f -> endswith(f, ".jl"), split(out, '\n'; keepempty = false)))
end
src(f) = read(`git -C $repo show $rev:$f`, String)
# code without comments and docstrings
function code_of(s::String)
    s = replace(s, r"\"\"\"(.|\n)*?\"\"\""m => "")            # docstrings and triple-quoted strings
    s = replace(s, r"#=(.|\n)*?=#"m => "")                     # block comments
    lines = String[]
    for l in split(s, '\n')
        # a comment to the end of the line, outside a string (a rough reading: the first # outside quotes)
        inq = false; cut = lastindex(l) + 1
        for (i, c) in pairs(l)
            c == '"' && (inq = !inq)
            if c == '#' && !inq; cut = i; break; end
        end
        push!(lines, l[1:prevind(l, cut)])
    end
    join(lines, '\n')
end
codes = Dict(f => code_of(src(f)) for f in files)
traits = Set(["Callable", "All", "HasLength", "Iterable", "Indexable", "MutableIndexable", "Resizable", "Keyed", "Solvable",
              "LinearOp", "BoundedText", "HasProperty", "IO"])
for (_, c) in codes, m in eachmatch(r"@trait\s+([A-Z]\w*)", c); push!(traits, m.captures[1]); end
pat = Dict(
    :keep => r"(?<![\w.])keep\(",
    :cast => r"(?<![\w.])(compiled_for|with_dynamic)\(",
    :Erased => r"(?<![\w.])Erased\b",
    :kept_call => r"(?<![\w.])(Kept\{|kept_call\()",
    :box => r"(?<![\w.])Dynamic\{[^}]*(\{[^}]*\}[^}]*)*\}\(",
    :erasing => r"@erasing\b",
    :unwrap => r"(?<![\w.])unwrap\(",
)
counts = Dict(k => 0 for k in KINDS)
perfile = Dict{String,Dict{Symbol,Int}}()
for f in files
    c = codes[f]
    pf = Dict(k => 0 for k in KINDS)
    for (k, p) in pat
        pf[k] += length(collect(eachmatch(p, c)))
    end
    for m in eachmatch(r"@nospecialize\(\s*\w*\s*::\s*([A-Z]\w*)", c)
        m.captures[1] in traits && (pf[:nospec_trait] += 1)
    end
    for k in KINDS; counts[k] += pf[k]; end
    any(>(0), values(pf)) && (perfile[f] = pf)
end
println("# ", repo, " @ ", rev, " (", strip(read(`git -C $repo rev-parse --short $(rev * "^{commit}")`, String)), "): ", join(dirs, " "), "; ", length(files), " files")
println("| kind | ", join(string.(KINDS), " | "), " | choosing (keep + cast + Erased + kept_call + nospec_trait) |")
println("|---|", repeat("---|", length(KINDS) + 1))
choose = counts[:keep] + counts[:cast] + counts[:Erased] + counts[:kept_call] + counts[:nospec_trait]
println("| all | ", join([counts[k] for k in KINDS], " | "), " | ", choose, " |")
for f in sort(collect(keys(perfile)))
    pf = perfile[f]
    println("| ", f, " | ", join([pf[k] for k in KINDS], " | "), " | ",
            pf[:keep] + pf[:cast] + pf[:Erased] + pf[:kept_call] + pf[:nospec_trait], " |")
end
