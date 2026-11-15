# E-431 (W-155b, D-9): the methods that extend another package's internal function.
#     julia --project=<env> census.jl [csv] <package>...
# With a csv file first, the forks' or upstream's work runs after the loads (E-392's session), so the
# facts code a session compiles is counted too.
# A method counts where its function (the singleton of its signature's first type, a closure's type
# included) belongs to another owner than the method's module, that owner names the definer no joint
# owner, and the function's name is neither exported nor `public` in its module. By the function's module:
#   (a) the module declares `facts`: the method is a pirate's under D-9's default (facts §1, §3);
#   (b) a package's module that does not declare `facts`: a pirate's once it declares it (the path's first step);
#   (c) Julia's own (Core, Base, the compiler, the standard libraries): outside the default.
# For (a) and (b): whether the owner's own code compiled by facts calls the function (an edge from it to an
# instance of one of the function's methods), and whether code compiled by facts relies on this method
# (an edge to an instance of it): such a method wins at a fact of the owner's code, whoever came first.
const ARGV = copy(ARGS)
const csv = !isempty(ARGV) && endswith(ARGV[1], ".csv") ? popfirst!(ARGV) : nothing
for p in ARGV; Core.eval(Main, Meta.parse("using $p")); end
if csv !== nothing
    w = @eval () -> (df = CSV.read($csv, DataFrame); d = describe(df); c = names(df)[1]; s = sort(df, c);
                     g = combine(groupby(df, names(df)[end]), c => sum); string(hash(repr((d, first(s, 3), g))); base = 16))
    Base.invokelatest(w)
end
const FACTS = 0x20
const STD = Set(Symbol.(readdir(Sys.STDLIB)))
function owner(m::Module)
    r = Base.moduleroot(m)
    (r === Base || r === Core || r === Base.Compiler || nameof(r) in STD) && return :Julia
    v = get(Base.EXT_PRIMED, Base.PkgId(r), nothing)              # an extension counts as its parent
    if v !== nothing
        p = get(Base.loaded_modules, first(v), nothing)
        p === nothing || return owner(p)
    end
    return r
end
joint(@nospecialize(o), @nospecialize(d)) = o isa Module && d isa Module && isdefined(o, :__tw_joint_owners__) &&
    nameof(d) in getfield(o, :__tw_joint_owners__)
declares_facts(m::Module) = ccall(:jl_get_module_facts, Cint, (Any,), m) == 1
isfactsci(ci) = ci isa Core.CodeInstance && ci.owner === nothing && (ci.flags & FACTS) != 0 && ci.max_world == typemax(UInt)
# the CodeInstances that hold an edge to an instance of `m`
function facts_callers(m::Method)
    out = Core.CodeInstance[]
    for mi in Base.specializations(m)
        mi isa Core.MethodInstance && isdefined(mi, :backedges) || continue
        for x in mi.backedges
            isfactsci(x) && push!(out, x)
        end
    end
    out
end
callerroot(ci) = (d = Base.Compiler.get_ci_mi(ci).def; d isa Method ? owner(d.module) : nothing)

rows = Dict{Symbol,Vector{Any}}(:a => Any[], :b => Any[], :c => Any[])
nall = 0; npkg = 0
Base.visit(Core.methodtable) do m
    global nall += 1
    definer = owner(m.module)
    definer === :Julia && return
    global npkg += 1
    b = Base.unwrap_unionall(m.sig)
    b isa DataType && !isempty(b.parameters) || return
    ft = Base.unwrap_unionall(b.parameters[1])
    ft isa DataType && isdefined(ft, :instance) && ft <: Function || return     # a function, not a type's constructor
    fm = ft.name.module
    name = ft.name.singletonname
    fo = owner(fm)
    (fo === definer || joint(fo, definer)) && return
    startswith(string(name), "#") && return                                   # another module's closure: not counted
    Base.ispublic(fm, name) && return
    k = fo === :Julia ? :c : declares_facts(fm) ? :a : :b
    push!(rows[k], (m, fm, name, fo, definer))
end
println("# E-431 census | ", join(ARGV, " "), csv === nothing ? "" : " | with the work on $(basename(csv))",
        " | Julia ", Base.GIT_VERSION_INFO.commit_short, " | methods ", nall, ", by packages ", npkg)
for (k, what) in ((:a, "(a) of a function whose module declares `facts`: pirates under D-9's default"),
                  (:b, "(b) of a package's internal function whose module does not declare `facts`"),
                  (:c, "(c) of Julia's internal functions (outside the default)"))
    rs = rows[k]
    owners = Dict{String,Int}(); pairs = Dict{String,Int}()
    calls = 0; relied = 0; relied_owner = 0; ex = String[]
    for (m, fm, name, fo, definer) in rs
        p = string(definer, " → ", fo); pairs[p] = get(pairs, p, 0) + 1
        if k != :c
            # does the owner's own facts code call the function at all?
            own = false
            for m2 in methods(getfield(fm, name))
                for c in facts_callers(m2)
                    callerroot(c) === fo && (own = true; break)
                end
                own && break
            end
            calls += own
            fc = facts_callers(m)
            relied += !isempty(fc)
            relied_owner += any(c -> callerroot(c) === fo, fc)
            length(ex) < 12 && push!(ex, string(m.module, ": ", fm, ".", name, " ", first(string(m.sig), 110),
                                                own ? " | the owner's facts code calls it" : "",
                                                isempty(fc) ? "" : " | relied on by $(length(fc)) facts instance(s)"))
        end
    end
    println("\n", what, ": ", length(rs), " methods")
    println("  by definer → owner: ", join(["$p $n" for (p, n) in sort(collect(pairs); by = last, rev = true)[1:min(end, 15)]], "; "))
    if k != :c
        println("  the owner's own code compiled by facts calls the function: ", calls,
                " | code compiled by facts relies on the method: ", relied, " (the owner's code: ", relied_owner, ")")
        for e in ex; println("    ", e); end
    end
end
