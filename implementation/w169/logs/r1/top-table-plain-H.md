`table-plain-H-trace-2.trace`: 25 compiles dispatched, 209 ms (the harness's 16, 741 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 73 |
| recompile | 0 | 0 |
| own image | 0 | 0 |
| composition | 0 | 0 |
| julia | 22 | 136 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 65.0 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 31.0 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 16.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 6.6 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.7 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.2 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.8 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.5 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}, Int64}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.2 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.8 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:label,), Tuple{String}}, typeof(Core.invokelatest), Function, String}` |
| 3.7 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofBottom}` |
| 3.6 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Int64}` |
| 3.5 | julia | `Tuple{typeof(Base.setindex!), Array{String, 1}, String, Int64}` |
| 3.0 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:digits,), Tuple{Int64}}, typeof(Base.round), Float64}` |
| 2.9 | julia | `Tuple{Type{NamedTuple{(:label,), T} where T<:Tuple}, Tuple{String}}` |
| 2.9 | julia | `Tuple{Type{NamedTuple{(:context,), T} where T<:Tuple}, Tuple{Pair{Symbol, Module}}}` |

`table-plain-H-trace-2.census`: 79 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | julia | 70 | 23 | 77 |
| image, no machine code | julia | 7 | 0 | 22 |
| inferred in the session | session | 1 | 4 | 13 |
| inferred in the session | own image | 1 | 0 | 0 |
| all | | 79 | 28 | 112 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 4.3 + 13.1 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 1.6 + 11.7 | session | julia | `Tuple{typeof(Base.mapreduce_impl), typeof(Base.identity), typeof(Base.add_sum), Base.Vector{Float64}, Int64, Int64, Int64}` |
| 0.4 + 8.9 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.3 + 8.5 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.5 + 7.8 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, Float64, String}` |
| 0.5 + 6.8 | session | julia | `Tuple{typeof(Base.hidigit), Float64, Int64}` |
| 0.9 + 4.5 | session | julia | `Tuple{typeof(Base.show), CoreSTDOUT, Float64, Bool, Bool}` |
| 0.6 + 4.4 | session | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 0.3 + 4.0 | session | julia | `Tuple{typeof(Base._array_for), Type{String}, Base.Vector{Base.SubString{String}}, Base.HasShape{1}}` |
| 0.0 + 4.1 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}, Int64}` |
| 0.0 + 3.8 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}}` |
| 0.2 + 3.3 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |

