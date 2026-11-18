# E-234: does the cache's image hold a valid CodeInstance for signatures the cached session still compiled?
#     julia --project=env_cache_fk probe_cached.jl
using CSV, DataFrames, Statistics, Dates, SessionCacheFk1
using TraitWorld
sigs = Any[
    Tuple{typeof(TraitWorld.enter_callable), Type{Tuple{Union{Missing, Float64}}}, Type{Bool}, Any, Any, Val{false}},
    Tuple{typeof(get!), DataFrames.var"#batch_compacttype##2#batch_compacttype##3"{Type{Union{Missing, Int64}}, Int64}, Dict{Any, String}, Type{Union{Missing, Int64}}},
    Tuple{typeof(Base.Compiler.typeinf_code), Base.Compiler.NativeInterpreter, Core.MethodMatch, Bool},
    Tuple{typeof(CSV.write), String, DataFrame},
    Tuple{typeof(show), IOContext{IOBuffer}, MIME{Symbol("text/plain")}, DataFrame},
]
w = Base.get_world_counter()
for T in sigs
    ms = Base._methods_by_ftype(T, -1, w)
    mi = Base.Compiler.specialize_method(ms[1])
    cis = Any[]; ci = isdefined(mi, :cache) ? mi.cache : nothing
    while ci isa Core.CodeInstance
        push!(cis, (owner = ci.owner, valid = ci.max_world == typemax(UInt), min = ci.min_world, native = ci.invoke != C_NULL || ci.specptr != C_NULL))
        ci = isdefined(ci, :next) ? ci.next : nothing
    end
    println("K ", first(string(T), 110), "\n   ", isempty(cis) ? "no CodeInstance" : cis)
end
