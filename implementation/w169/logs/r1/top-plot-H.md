`plot-H-trace-2.trace`: 44 compiles dispatched, 371 ms (the harness's 16, 747 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 126 |
| recompile | 2 | 49 |
| own image | 1 | 0 |
| composition | 0 | 0 |
| julia | 38 | 196 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 118.2 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 47.1 | recompile | `Tuple{typeof(Base._atexit), Int32}` |
| 33.1 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 16.6 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 8.8 | julia | `Tuple{typeof(Base.getindex), Core.SimpleVector, Base.UnitRange{Int64}}` |
| 6.4 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.6 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.6 | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Array{Symbol, 1}}}` |
| 5.1 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.8 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.6 | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Array{Symbol, 1}}, Tuple{Int64, Int64}}` |
| 4.6 | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}}` |
| 4.5 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}, Int64}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.3 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.2 | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}, Int64}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.9 | julia | `Tuple{typeof(Base.round), Type{Int64}, Float64}` |

`plot-H-trace-2.census`: 71 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | session | 1 | 47 | 28 |
| image, no machine code | julia | 23 | 0 | 74 |
| inferred in the session | julia | 37 | 12 | 61 |
| inferred in the session | own image | 10 | 8 | 13 |
| all | | 71 | 67 | 177 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 46.5 + 27.9 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 0.7 + 8.8 | session | julia | `Tuple{typeof(Base.getindex), Base.Vector{Float64}, Base.StepRange{Int64, Int64}}` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.5 + 8.6 | session | own image | `Tuple{TraitMakie.var"##lines#19", String, Tuple{Int64, Int64}, String, String, Base.Pairs{Symbol, Symbol, Nothing, @NamedTuple{color::Symbol}}, typeof` |
| 0.3 + 8.4 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.4 + 8.0 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, String, String}` |
| 0.0 + 8.2 | image | julia | `Tuple{typeof(Base.getindex), SimpleVector, Base.UnitRange{Int64}}` |
| 0.6 + 4.4 | session | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 0.3 + 4.5 | session | own image | `Tuple{TraitMakie.var"##scatter!#4", Base.Pairs{Symbol, Symbol, Nothing, @NamedTuple{color::Symbol}}, typeof(TraitMakie.scatter!), TraitMakie.PlotCore.` |
| 0.0 + 4.8 | image | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Base.Vector{Symbol}}}` |
| 0.3 + 4.0 | session | julia | `Tuple{typeof(Base._array_for), Type{String}, Base.Vector{Base.SubString{String}}, Base.HasShape{1}}` |
| 0.0 + 4.2 | image | julia | `Tuple{typeof(Base.iterate), Base.Iterators.Enumerate{Base.Vector{Symbol}}, Tuple{Int64, Int64}}` |

