`report-plain-H-trace-2.trace`: 31 compiles dispatched, 261 ms (the harness's 16, 740 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 81 |
| recompile | 1 | 33 |
| own image | 2 | 2 |
| composition | 0 | 0 |
| julia | 25 | 144 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 73.5 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 33.1 | recompile | `Tuple{typeof(Base._atexit), Int32}` |
| 31.2 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 16.5 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.3 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 6.4 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.7 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.3 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.9 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.5 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}, Int64}` |
| 4.4 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.2 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.7 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:label,), Tuple{String}}, typeof(Core.invokelatest), Function, String}` |
| 3.7 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofBottom}` |
| 3.6 | julia | `Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64}` |
| 3.5 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Int64}` |
| 3.3 | julia | `Tuple{typeof(Base.merge), NamedTuple{(), Tuple{}}, Base.Pairs{Symbol, Symbol, Nothing, NamedTuple{(:color,), Tuple{Symbol}}}}` |
| 3.1 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:digits,), Tuple{Int64}}, typeof(Base.round), Float64}` |

`report-plain-H-trace-2.census`: 65 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | julia | 52 | 37 | 61 |
| image, no machine code | julia | 11 | 0 | 31 |
| inferred in the session | session | 1 | 13 | 14 |
| inferred in the session | own image | 1 | 0 | 2 |
| all | | 65 | 50 | 108 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 18.6 + 11.4 | session | julia | `Tuple{typeof(Base.mapreduce_impl), typeof(Base.identity), typeof(Base.add_sum), Base.Vector{Float64}, Int64, Int64, Int64}` |
| 13.4 + 13.9 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 0.4 + 8.9 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.4 + 8.2 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, String, String}` |
| 0.3 + 8.2 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.7 + 4.4 | session | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 0.4 + 4.0 | session | julia | `Tuple{typeof(Base._array_for), Type{String}, Base.Vector{Base.SubString{String}}, Base.HasShape{1}}` |
| 0.0 + 4.1 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}, Int64}` |
| 0.0 + 3.8 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}}` |
| 0.3 + 3.3 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 0.2 + 3.2 | session | julia | `Tuple{typeof(kwcall), @NamedTuple{exclude::Base.IdSet{CodeInstance}}, typeof(invokelatest), Function, String}` |
| 0.0 + 3.2 | image | julia | `Tuple{typeof(Base.setindex!), Base.Vector{String}, String, Int64}` |

