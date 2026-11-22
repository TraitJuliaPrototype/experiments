`ode-H-trace-2.trace`: 85 compiles dispatched, 743 ms (the harness's 17, 771 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 9 | 314 |
| recompile | 3 | 18 |
| own image | 10 | 82 |
| composition | 4 | 26 |
| julia | 59 | 303 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 196.1 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 80.8 | session | `Tuple{ODECore.PartialFn{typeof(Main.robertson!), Array{Float64, 1}}, Array{ForwardDiff.Dual{ODECore.ODETag, Float64, 8}, 1}, Array{ForwardDiff.Dual{ODECore.ODETag, Float6` |
| 31.5 | own image | `Tuple{ForwardDiff.var"##49#50", Vararg{Any, 4}}` |
| 30.5 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 22.2 | julia | `Tuple{typeof(Base.println), Core.CoreSTDOUT, String, Float64}` |
| 21.2 | own image | `Tuple{typeof(ForwardDiff.tupexpr), ForwardDiff.var"#52#53", Int64}` |
| 18.9 | julia | `Tuple{Type{Base.TwicePrecision{Float64}}, Tuple{Int128, Int128}}` |
| 16.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 12.4 | recompile | `Tuple{typeof(Base.setindex!), Base.IdDict{Any, Array{Any, 1}}, Any, Any}` |
| 11.8 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:sigdigits,), Tuple{Int64}}, typeof(Base.round), Float64}` |
| 11.1 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 9.4 | julia | `Tuple{typeof(Base.getindex), Core.SimpleVector, Base.UnitRange{Int64}}` |
| 8.7 | session | `Tuple{ODECore.PartialFn{typeof(Main.robertson!), Array{Float64, 1}}, Array{Float64, 1}, Array{Float64, 1}, Float64}` |
| 8.6 | session | `Tuple{ODECore.PartialFn{typeof(Main.lorenz!), Array{Float64, 1}}, Array{Float64, 1}, Array{Float64, 1}, Float64}` |
| 7.9 | own image | `Tuple{typeof(ODECore._problem_of), Core.Dynamic{Core.Callable{Tuple{Array{Float64, 1}, Array{Float64, 1}, Array{Float64, 1}, Float64}, Nothing}}, Function, Array{Float64,` |
| 7.7 | composition | `Tuple{typeof(ODECore._problem), Core.Dynamic{All{Core.Callable{Tuple{Array{Float64, 1}, Array{Float64, 1}, Float64}, Nothing}, Core.Callable{Tuple{Array{ForwardDiff.Dual{` |
| 7.5 | composition | `Tuple{typeof(Core.kwcall), NamedTuple{(:saveat, :reltol, :abstol), Tuple{Array{Float64, 1}, Float64, Float64}}, typeof(TraitDifferentialEquations.solve), ODECore.ODEProbl` |
| 7.3 | composition | `Tuple{typeof(Core.kwcall), NamedTuple{(:saveat, :reltol, :abstol), Tuple{Array{Float64, 1}, Float64, Float64}}, typeof(TraitDifferentialEquations.solve), ODECore.ODEProbl` |
| 6.3 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |

`ode-H-trace-2.census`: 349 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | session | 31 | 208 | 61 |
| inferred in the session | julia | 217 | 76 | 148 |
| inferred in the session | own image | 46 | 81 | 41 |
| image, no machine code | julia | 22 | 0 | 68 |
| inferred in the session | recompile | 13 | 27 | 6 |
| inferred in the session | composition | 20 | 7 | 22 |
| all | | 349 | 399 | 347 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 128.4 + 23.6 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 63.7 + 2.0 | session | session | `Tuple{ODECore.PartialFn{typeof(Main.robertson!), Base.Vector{Float64}}, Base.Vector{ForwardDiff.Dual{ODECore.ODETag, Float64, 8}}, Base.Vector{Forward` |
| 60.5 + 0.0 | session | own image | `Tuple{typeof(Base.:+), ForwardDiff.Partials{8, Float64}, ForwardDiff.Partials{8, Float64}}` |
| 21.0 + 0.0 | session | recompile | `Tuple{typeof(Base.promote), Int64, Real}` |
| 1.4 + 17.0 | session | julia | `Tuple{Type{Base.TwicePrecision{Float64}}, Tuple{Int128, Int128}}` |
| 2.4 + 13.1 | session | session | `Tuple{typeof(Main.robertson!), Base.Vector{ForwardDiff.Dual{ODECore.ODETag, Float64, 8}}, Base.Vector{ForwardDiff.Dual{ODECore.ODETag, Float64, 8}}, B` |
| 12.4 + 0.0 | session | julia | `Tuple{typeof(Base.range_start_stop_length), Float64, Float64, Int64}` |
| 1.2 + 10.6 | session | own image | `Tuple{typeof(Base.collect), Base.Generator{Base.UnitRange{Int64}, ForwardDiff.var"#tupexpr##0#tupexpr##1"{ForwardDiff.var"#52#53"}}}` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.0 + 8.7 | image | julia | `Tuple{typeof(Base.getindex), SimpleVector, Base.UnitRange{Int64}}` |
| 0.3 + 8.1 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 2.0 + 6.5 | session | recompile | `Tuple{typeof(Base.setindex!), Base.IdDict{Any, Base.Vector{Any}}, Any, Any}` |

