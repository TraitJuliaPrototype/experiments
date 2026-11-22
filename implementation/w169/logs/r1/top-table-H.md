`table-H-trace-2.trace`: 29 compiles dispatched, 235 ms (the harness's 16, 764 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 73 |
| recompile | 0 | 0 |
| own image | 0 | 0 |
| composition | 0 | 0 |
| julia | 26 | 162 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 65.1 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 33.8 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 16.6 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 9.1 | julia | `Tuple{typeof(Base.getindex), Core.SimpleVector, Base.UnitRange{Int64}}` |
| 6.5 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 6.2 | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Array{Symbol, 1}}}` |
| 5.6 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.2 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.9 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.6 | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Array{Symbol, 1}}, Tuple{Int64, Int64}}` |
| 4.5 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}, Int64}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.2 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.8 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:label,), Tuple{String}}, typeof(Core.invokelatest), Function, String}` |
| 3.8 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofBottom}` |
| 3.6 | julia | `Tuple{Type{Ref{Any}}, Type}` |
| 3.5 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Int64}` |

`table-H-trace-2.census`: 83 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | julia | 72 | 24 | 79 |
| image, no machine code | julia | 10 | 0 | 40 |
| inferred in the session | session | 1 | 4 | 14 |
| all | | 83 | 28 | 133 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 4.0 + 13.6 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 1.7 + 11.4 | session | julia | `Tuple{typeof(Base.mapreduce_impl), typeof(Base.identity), typeof(Base.add_sum), Base.Vector{Float64}, Int64, Int64, Int64}` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.3 + 8.2 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.0 + 8.4 | image | julia | `Tuple{typeof(Base.getindex), SimpleVector, Base.UnitRange{Int64}}` |
| 0.5 + 7.5 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, Float64, String}` |
| 0.6 + 6.8 | session | julia | `Tuple{typeof(Base.hidigit), Float64, Int64}` |
| 1.0 + 4.5 | session | julia | `Tuple{typeof(Base.show), CoreSTDOUT, Float64, Bool, Bool}` |
| 0.0 + 5.3 | image | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Base.Vector{Symbol}}}` |
| 0.6 + 4.3 | session | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 0.3 + 4.1 | session | julia | `Tuple{typeof(Base._array_for), Type{String}, Base.Vector{Base.SubString{String}}, Base.HasShape{1}}` |
| 0.0 + 4.2 | image | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Base.Vector{Symbol}}, Tuple{Int64, Int64}}` |

