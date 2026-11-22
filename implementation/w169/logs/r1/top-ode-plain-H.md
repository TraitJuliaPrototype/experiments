`ode-plain-H-trace-2.trace`: 62 compiles dispatched, 622 ms (the harness's 17, 778 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 6 | 365 |
| recompile | 0 | 0 |
| own image | 1 | 0 |
| composition | 0 | 0 |
| julia | 55 | 257 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 336.6 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 32.9 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 18.8 | julia | `Tuple{Type{Base.TwicePrecision{Float64}}, Tuple{Int128, Int128}}` |
| 16.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 9.0 | session | `Tuple{Type{FunctionWrappers.FunctionWrapper{Nothing, Tuple{Array{ForwardDiff.Dual{PlainODE.ODETag, Float64, 3}, 1}, Array{ForwardDiff.Dual{PlainODE.ODETag, Float64, 3}, 1` |
| 6.4 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.9 | session | `Tuple{Type{FunctionWrappers.FunctionWrapper{Nothing, Tuple{Array{Float64, 1}, Array{Float64, 1}, Array{Float64, 1}, Float64}}}, typeof(Main.lorenz!)}` |
| 5.6 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.6 | session | `Tuple{Type{FunctionWrappers.FunctionWrapper{Nothing, Tuple{Array{Float64, 1}, Array{Float64, 1}, Array{Float64, 1}, Float64}}}, typeof(Main.robertson!)}` |
| 5.5 | julia | `Tuple{typeof(Base.checkbounds), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}, Int64}` |
| 5.4 | julia | `Tuple{typeof(Base.checkbounds), Base.Broadcast.Broadcasted{Nothing, Tuple{Base.OneTo{Int64}}, typeof(Base.exp10), Tuple{Base.Broadcast.Extruded{Base.StepRangeLen{Float64,` |
| 5.3 | julia | `Tuple{typeof(Base.getproperty), Base.Broadcast.Extruded{Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}, Tuple{Bool}, Tuple{` |
| 5.2 | julia | `Tuple{typeof(Base.prevfloat), Float64}` |
| 5.1 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.9 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.4 | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.3 | julia | `Tuple{typeof(Base.iterate), Base.StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}, Int64}` |

`ode-plain-H-trace-2.census`: 289 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | julia | 202 | 92 | 137 |
| inferred in the session | session | 52 | 161 | 59 |
| inferred in the session | own image | 9 | 66 | 13 |
| image, no machine code | julia | 21 | 0 | 57 |
| inferred in the session | composition | 5 | 1 | 0 |
| all | | 289 | 320 | 267 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 121.1 + 21.4 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 42.2 + 0.0 | session | own image | `Tuple{typeof(PlainODE.solve_ode), PlainODE.WrappedAD{Base.Vector{Float64}}, Base.Vector{Float64}, Tuple{Float64, Float64}, PlainODE.Rodas5, Base.Vecto` |
| 18.7 + 5.3 | session | session | `Tuple{Type{FunctionWrappers.FunctionWrapper{Nothing, Tuple{Base.Vector{Float64}, Base.Vector{Float64}, Base.Vector{Float64}, Float64}}}, typeof(Main.l` |
| 20.0 + 0.0 | session | own image | `Tuple{typeof(PlainODE.rodas5_step!), PlainODE.WrappedAD{Base.Vector{Float64}}, PlainODE.Rodas5Integrator{Base.Vector{Float64}}, Float64, Float64, Floa` |
| 1.4 + 16.8 | session | julia | `Tuple{Type{Base.TwicePrecision{Float64}}, Tuple{Int128, Int128}}` |
| 16.4 + 0.0 | session | julia | `Tuple{typeof(Base.print_to_string), String, Float64, String, Float64}` |
| 12.6 + 0.0 | session | julia | `Tuple{typeof(Base.range_start_stop_length), Float64, Float64, Int64}` |
| 1.9 + 8.4 | session | session | `Tuple{typeof(Main.robertson!), Base.Vector{ForwardDiff.Dual{PlainODE.ODETag, Float64, 3}}, Base.Vector{ForwardDiff.Dual{PlainODE.ODETag, Float64, 3}},` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.3 + 8.2 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 8.4 + 0.0 | session | julia | `Tuple{typeof(Base._linspace), Float64, Float64, Int64}` |
| 0.4 + 7.8 | session | own image | `Tuple{PlainODE.var"##solve#20", Nothing, Base.Pairs{Symbol, Any, Nothing, @NamedTuple{saveat::Base.Vector{Float64}, reltol::Float64, abstol::Float64}}` |

