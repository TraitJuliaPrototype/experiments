`plot-plain-H-trace-2.trace`: 40 compiles dispatched, 362 ms (the harness's 16, 751 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 147 |
| recompile | 1 | 33 |
| own image | 1 | 0 |
| composition | 0 | 0 |
| julia | 35 | 181 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 139.4 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 34.2 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 33.3 | recompile | `Tuple{typeof(Base._atexit), Int32}` |
| 16.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 6.4 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.7 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.2 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.9 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.6 | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}}` |
| 4.5 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}, Int64}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.3 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.3 | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}, Int64}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.9 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofBottom}` |
| 3.9 | julia | `Tuple{typeof(Base.trunc), Type{Int64}, Float64}` |
| 3.9 | julia | `Tuple{typeof(Base.round), Type{Int64}, Float64}` |
| 3.8 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:label,), Tuple{String}}, typeof(Core.invokelatest), Function, String}` |

`plot-plain-H-trace-2.census`: 67 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | session | 1 | 49 | 28 |
| inferred in the session | julia | 36 | 12 | 62 |
| image, no machine code | julia | 20 | 0 | 58 |
| inferred in the session | own image | 10 | 26 | 13 |
| all | | 67 | 87 | 162 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 48.8 + 28.1 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 17.8 + 0.0 | session | own image | `Tuple{typeof(kwcall), @NamedTuple{color::Symbol}, typeof(PlainPlots.lines!), PlainPlots.Figure, Base.Matrix{Float64}}` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.7 + 8.5 | session | julia | `Tuple{typeof(Base.getindex), Base.Vector{Float64}, Base.StepRange{Int64, Int64}}` |
| 0.4 + 8.7 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, String, String}` |
| 0.3 + 8.2 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.4 + 7.4 | session | own image | `Tuple{PlainPlots.var"##lines#24", String, Tuple{Int64, Int64}, String, String, Base.Pairs{Symbol, Symbol, Nothing, @NamedTuple{color::Symbol}}, typeof` |
| 0.3 + 5.9 | session | own image | `Tuple{PlainPlots.var"##scatter!#9", Base.Pairs{Symbol, Symbol, Nothing, @NamedTuple{color::Symbol}}, typeof(PlainPlots.scatter!), PlainPlots.Figure, B` |
| 0.6 + 4.4 | session | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 0.3 + 4.1 | session | julia | `Tuple{typeof(Base._array_for), Type{String}, Base.Vector{Base.SubString{String}}, Base.HasShape{1}}` |
| 0.0 + 4.1 | image | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}}` |
| 0.0 + 4.1 | image | julia | `Tuple{typeof(Base.iterate), Base.Vector{Base.SubString{String}}, Int64}` |

