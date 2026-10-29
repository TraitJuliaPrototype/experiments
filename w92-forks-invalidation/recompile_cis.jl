# E-238: why the compile trace marks a root `# recompile` (gf.c: the MethodInstance already has a CodeInstance
# with machine code, of any owner and any world). For the session's largest such roots: their CodeInstances
# after the imports (owner, worlds, machine code), then after the step that compiles them (a script, not the REPL).
using CSV, DataFrames, Statistics, Dates
_cis(mi) = (out = Core.CodeInstance[]; ci = isdefined(mi, :cache) ? mi.cache : nothing;
            while ci isa Core.CodeInstance; push!(out, ci); ci = isdefined(ci, :next) ? ci.next : nothing; end; out)
W = Base.get_world_counter()
const SIGS = Any[
    Tuple{typeof(Core.kwcall), NamedTuple{(:copycols, :keeprows, :renamecols), Tuple{Bool, Bool, Bool}}, typeof(DataFrames.manipulate), DataFrames.DataFrame, Any, Any, Vararg{Any}},
    Tuple{typeof(Base.Compiler.typeinf_code), Base.Compiler.NativeInterpreter, Core.MethodMatch, Bool},
    Tuple{typeof(Base.length), Vector{Float64}},
    Tuple{typeof(Base.copy), Vector{Bool}},
    Tuple{typeof(Base.copy), Vector{Union{Missing, Int64}}},
    Tuple{typeof(Base.getindex), Vector{Float64}, Int64},
    Tuple{typeof(Base.AnnotatedDisplay.ansi_write), typeof(Base.write), Base.IOContext{Base.Terminals.TerminalBuffer}, SubString{Base.AnnotatedString{String}}},
]
# the kwbody of manipulate: found through the method table
kwb = [m for m in methods(getfield(DataFrames, Symbol("#manipulate#630")))]
println("kwbody methods: ", length(kwb))
function show_cis(label)
    println("== ", label, " (world ", Base.get_world_counter(), ", load mark ", W, ")")
    mis = Any[]
    for T in SIGS
        mi = Base.method_instances(T isa Type ? T : T, Base.get_world_counter())
        mi = Base.Compiler.specialize_method(Base.Compiler.findsup(T, Base.Compiler.InternalMethodTable(Base.get_world_counter()))[1])
        push!(mis, (T, mi))
    end
    for m in kwb, mi in Base.specializations(m); push!(mis, (mi.specTypes, mi)); end
    for (T, mi) in mis
        println(first(sprint(show, T), 140))
        for ci in _cis(mi)
            println("    owner ", repr(ci.owner), " worlds ", ci.min_world, "–", ci.max_world == typemax(UInt) ? "∞" : ci.max_world,
                    " machine code ", ci.invoke != C_NULL)
        end
    end
end
show_cis("after the imports")
df = CSV.read(joinpath(ENV["DATA"], "people.csv"), DataFrame)
sub = subset(select(df, :id, :city, :income), :income => ByRow(x -> !ismissing(x) && x > 5e4))
show_cis("after select and subset")
