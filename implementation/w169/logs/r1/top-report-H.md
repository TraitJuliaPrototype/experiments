`report-H-trace-2.trace`: 36 compiles dispatched, 250 ms (the harness's 16, 741 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 59 |
| recompile | 1 | 33 |
| own image | 3 | 8 |
| composition | 0 | 0 |
| julia | 29 | 149 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 51.9 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 32.9 | recompile | `Tuple{typeof(Base._atexit), Int32}` |
| 19.8 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 12.3 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 10.8 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.8 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 8.9 | julia | `Tuple{typeof(Base.getindex), Core.SimpleVector, Base.UnitRange{Int64}}` |
| 6.4 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.8 | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Array{Symbol, 1}}}` |
| 5.6 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 4.9 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.8 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.7 | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Array{Symbol, 1}}, Tuple{Int64, Int64}}` |
| 4.5 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}, Int64}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.2 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.2 | own image | `Tuple{typeof(Base.push!), Array{TraitTables.TableCore.Column{T} where T, 1}, Array{Union{Base.Missing, Float64}, 1}}` |
| 4.1 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofBottom}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.9 | own image | `Tuple{typeof(Base.push!), Array{TraitTables.TableCore.Column{T} where T, 1}, Array{Union{Base.Missing, Int64}, 1}}` |

`report-H-trace-2.census`: 71 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | julia | 54 | 20 | 63 |
| image, no machine code | julia | 14 | 0 | 48 |
| inferred in the session | session | 1 | 10 | 14 |
| image, no machine code | own image | 2 | 0 | 7 |
| all | | 71 | 30 | 132 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 9.8 + 13.5 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 1.6 + 10.8 | session | julia | `Tuple{typeof(Base.mapreduce_impl), typeof(Base.identity), typeof(Base.add_sum), Base.Vector{Float64}, Int64, Int64, Int64}` |
| 0.4 + 8.9 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.3 + 8.4 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.4 + 8.3 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, String, String}` |
| 0.0 + 8.3 | image | julia | `Tuple{typeof(Base.getindex), SimpleVector, Base.UnitRange{Int64}}` |
| 0.0 + 5.0 | image | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Base.Vector{Symbol}}}` |
| 0.6 + 4.3 | session | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 0.3 + 4.0 | session | julia | `Tuple{typeof(Base._array_for), Type{String}, Base.Vector{Base.SubString{String}}, Base.HasShape{1}}` |
| 0.0 + 4.2 | image | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Base.Vector{Symbol}}, Tuple{Int64, Int64}}` |
| 0.0 + 4.1 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}, Int64}` |
| 0.0 + 3.8 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}}` |

