# Does a top-level push! of a type value into a Type[] create a specialization for the value's exact type?
count_exact(f) = sum(m -> count(mi -> (u = Base.unwrap_unionall(mi.specTypes); u isa DataType && u.hash == 0), Base.specializations(m)), methods(f))
v = Type[]
before = count_exact(Base._push!)
for T in (Union{Tuple{Int, Float64}, Tuple{Int}}, Union{Tuple{Int8, Float64}, Tuple{Int8}}, Union{Tuple{Int16, Float64}, Tuple{Int16}})
    push!(v, T)
end
push!(v, Union{Tuple{Int32, Float64}, Tuple{Int32}})        # at top level, outside a loop
println("facts mode: ", Base.Compiler.facts_default(), "; _push! specializations without hash: ", before, " -> ", count_exact(Base._push!))
for m in methods(Base._push!), mi in Base.specializations(m)
    u = Base.unwrap_unionall(mi.specTypes); u isa DataType && u.hash == 0 && occursin("Int32", string(mi.specTypes)) && println("  ", mi.specTypes)
end
