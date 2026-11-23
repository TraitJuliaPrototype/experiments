# The negative-sites report (W-171, E-544): every place in the compiler's source that decides by an empty type
# intersection (`hasintersect`, `typeintersect(…) === Bottom` and its spellings), with whether the place is gated for
# a set (compiler §4.8: an empty intersection about a set that a membership could change is no proof, unless the
# frame records the pair's edge). A site is "gated" where it calls `may_intersect` or where `negative_fold_blocked`
# is asked within its function; else it is listed as "open", with the argument types the reader must judge (a
# constant type such as `Symbol` or `Int` could only meet a set by a membership of that type).
#
#     julia experiments/implementation/audit/negative_sites.jl <julia tree> [--open]
#
# It reads the source only; it asserts nothing.
tree = isempty(ARGS) ? error("usage: negative_sites.jl <julia tree> [--open]") : ARGS[1]
onlyopen = "--open" in ARGS
src = joinpath(tree, "Compiler", "src")
files = String[]
for (d, _, fs) in walkdir(src), f in fs
    endswith(f, ".jl") && push!(files, joinpath(d, f))
end
const PAT = r"(?<![A-Za-z_])(hasintersect|may_intersect)\(|typeintersect\([^)]*\)\s*(===|!==|==|!=)\s*(Bottom|Union\{\})"
const CONST_ARG = r"hasintersect\([^,]*,\s*(Symbol|Int|Bool|Type|TypeVar|Module|Nothing|Builtin|Ptr|Core\.OpaqueClosure|GenericMemory|GenericMemoryRef|Union\{[A-Za-z, ]*\})\)"
nsites = 0; nopen = 0; nconst = 0
for f in sort(files)
    lines = readlines(f)
    # the function each line is in: the last line at column 0 that starts a definition
    fstart = zeros(Int, length(lines))
    cur = 1
    for (i, l) in enumerate(lines)
        if occursin(r"^(@nospecs\s+)?(function|[A-Za-z_!][A-Za-z0-9_!.]*\(.*\)\s*=)", l) || occursin(r"^@nospecs function", l)
            cur = i
        end
        fstart[i] = cur
    end
    for (i, l) in enumerate(lines)
        occursin(PAT, l) || continue
        startswith(lstrip(l), "#") && continue
        occursin(r"^(may_intersect|hasintersect)\(@nospecialize", lstrip(l)) && continue   # the definitions
        global nsites += 1
        a = fstart[i]; b = i
        while b < length(lines) && !(b > i && fstart[b+1] != fstart[i]); b += 1; end
        body = join(lines[a:min(b, length(lines))], '\n')
        gated = occursin("may_intersect(", l) || occursin("negative_fold_blocked", body)
        constarg = occursin(CONST_ARG, l)
        kind = gated ? "gated" : constarg ? "constant" : "open"
        kind == "open" && (global nopen += 1)
        kind == "constant" && (global nconst += 1)
        (onlyopen && kind != "open") && continue
        println(rpad(kind, 9), relpath(f, src), ":", i, "  ", strip(l))
    end
end
println("negative_sites: $nsites sites, $(nsites - nopen - nconst) gated, $nconst against a constant type, $nopen open")
