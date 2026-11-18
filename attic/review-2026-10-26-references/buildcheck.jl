C = Base.Compiler
println("VERSION=", VERSION, " commit=", Base.GIT_VERSION_INFO.commit[1:10], " date=", Base.GIT_VERSION_INFO.date_string)
for s in (:fact_splits_ok, :union_split_cost, :facts_const_call, :facts_const_prop_call, :tuple_splits, :is_fact_sig, :split_call, :known_type, :SplitTable, :MAX_SPLIT_TABLE_ARGS, :PlainRTInterp, :FACTS_IMAGE)
    println(rpad(string(s), 24), isdefined(C, s))
end
println("methods(is_fact_sig): ", length(methods(C.is_fact_sig)), " ", [m.sig for m in methods(C.is_fact_sig)])
println("facts_default()=", C.facts_default(), "  jl_compile_by_facts=", ccall(:jl_compile_by_facts, Cint, ()))
println("Base._split_table_miss! defined: ", isdefined(Base, :_split_table_miss!))
# closure-type recognition
clo = let a = 1; x -> x + a end
kw(x; y = 1) = x + y
println("is_closure_type(closure)=", C.is_closure_type(typeof(clo)), " singletonname=", typeof(clo).name.singletonname)
println("is_closure_type(typeof(sum))=", C.is_closure_type(typeof(sum)))
println("is_closure_type(Base.Fix1{typeof(+),Int})=", C.is_closure_type(Base.Fix1{typeof(+),Int}))
kwbody = only(methods(Core.kwcall, (NamedTuple, typeof(kw), Int)))
println("kwcall method module/name: ", kwbody.name, " is_closure_type(typeof(Core.kwcall))=", C.is_closure_type(typeof(Core.kwcall)))
# the keyword body function
bodyf = Base.bodyfunction(only(methods(kw, (Int,))))
println("kw body: ", bodyf, " is_closure_type=", C.is_closure_type(typeof(bodyf)))
println("is_fact_sig(Tuple{typeof(vcat),Vararg{Int}})=", C.is_fact_sig(Tuple{typeof(vcat),Vararg{Int}}))
println("is_fact_sig(Tuple{typeof(sum),Tuple{Union{Int,Missing},Float64}})=", C.is_fact_sig(Tuple{typeof(sum),Tuple{Union{Int,Missing},Float64}}))
