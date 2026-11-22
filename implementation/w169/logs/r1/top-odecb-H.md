`odecb-H-trace-2.trace`: 69 compiles dispatched, 488 ms (the harness's 17, 782 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 13 | 97 |
| recompile | 3 | 18 |
| own image | 22 | 149 |
| composition | 4 | 28 |
| julia | 27 | 196 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 33.5 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 31.2 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 24.8 | own image | `Tuple{typeof(ODECore.step_event_initialize!), ODECore.ParamEvent{Array{Float64, 1}, Float64, Array{Float64, 1}}, Array{Float64, 1}, Float64, Core.Dynamic{ODECore.StepView` |
| 22.0 | julia | `Tuple{typeof(Base.println), Core.CoreSTDOUT, String, Float64}` |
| 19.4 | own image | `Tuple{typeof(Base.push!), Array{ODECore.StepCallback{Array{Float64, 1}, Float64}, 1}, ODECore.ParamCallback{Array{Float64, 1}, Float64, Array{Float64, 1}}}` |
| 19.0 | own image | `Tuple{typeof(Base.push!), Array{ODECore.StepEvent{Array{Float64, 1}, Float64}, 1}, ODECore.ParamEvent{Array{Float64, 1}, Float64, Array{Float64, 1}}}` |
| 16.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 13.3 | composition | `Tuple{typeof(Core.kwcall), NamedTuple{(:callback, :reltol, :abstol), Tuple{Tuple{ODECore.ContinuousCallback}, Float64, Float64}}, typeof(TraitDifferentialEquations.solve)` |
| 12.4 | recompile | `Tuple{typeof(Base.setindex!), Base.IdDict{Any, Array{Any, 1}}, Any, Any}` |
| 11.9 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:sigdigits,), Tuple{Int64}}, typeof(Base.round), Float64}` |
| 11.5 | session | `Tuple{Type{ODECore.FunctionCallback{Array{Float64, 1}, Float64, Array{Float64, 1}, C, A, I} where I<:Core.Callable{Tuple{Array{Float64, 1}, Float64, Core.Dynamic{ODECore.` |
| 11.5 | session | `Tuple{Type{ODECore.FunctionEventCallback{Array{Float64, 1}, Float64, Array{Float64, 1}, C, A, N, I} where I<:Core.Callable{Tuple{Array{Float64, 1}, Float64, Core.Dynamic{` |
| 11.4 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 11.3 | own image | `Tuple{typeof(ODECore.event_affect_dir!), ODECore.ParamEvent{Array{Float64, 1}, Float64, Array{Float64, 1}}, Core.Dynamic{ODECore.StepView{Array{Float64, 1}, Float64}}, Bo` |
| 10.0 | julia | `Tuple{typeof(Base.Filesystem.joinpath), NTuple{7, String}}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 9.4 | julia | `Tuple{typeof(Base.getindex), Core.SimpleVector, Base.UnitRange{Int64}}` |
| 8.6 | session | `Tuple{ODECore.PartialFn{typeof(Main.lorenz!), Array{Float64, 1}}, Array{Float64, 1}, Array{Float64, 1}, Float64}` |
| 7.7 | own image | `Tuple{typeof(ODECore._problem_of), Core.Dynamic{Core.Callable{Tuple{Array{Float64, 1}, Array{Float64, 1}, Array{Float64, 1}, Float64}, Nothing}}, Function, Array{Float64,` |
| 7.4 | composition | `Tuple{typeof(ODECore._problem), Core.Dynamic{All{Core.Callable{Tuple{Array{Float64, 1}, Array{Float64, 1}, Float64}, Nothing}, Core.Callable{Tuple{Array{ForwardDiff.Dual{` |

`odecb-H-trace-2.census`: 227 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | own image | 55 | 20 | 107 |
| inferred in the session | julia | 78 | 21 | 87 |
| inferred in the session | session | 59 | 26 | 55 |
| image, no machine code | julia | 8 | 0 | 33 |
| inferred in the session | composition | 15 | 5 | 20 |
| image, no machine code | own image | 2 | 0 | 22 |
| inferred in the session | recompile | 9 | 5 | 6 |
| image, no machine code | composition | 1 | 0 | 3 |
| all | | 227 | 77 | 333 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 8.7 + 7.2 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 0.0 + 11.3 | image | own image | `Tuple{typeof(Base._growend_internal!), Base.Vector{ODECore.StepCallback{Base.Vector{Float64}, Float64}}, Int64, Int64}` |
| 0.0 + 11.0 | image | own image | `Tuple{typeof(Base._growend_internal!), Base.Vector{ODECore.StepEvent{Base.Vector{Float64}, Float64}}, Int64, Int64}` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.5 + 8.7 | session | own image | `Tuple{ODECore.var"##ODEProblem#22", ODECore.DiscreteCallback, Type{ODECore.ODEProblem}, Dynamic{Callable{Tuple{Base.Vector{Float64}, Base.Vector{Float` |
| 1.2 + 7.9 | session | julia | `Tuple{typeof(Base.Filesystem.joinpath), NTuple{7, String}}` |
| 0.8 + 8.1 | session | session | `Tuple{Type{ODECore.FunctionEventCallback{Base.Vector{Float64}, Float64, Base.Vector{Float64}, C, A, N, I} where {C<:Callable{Tuple{Base.Vector{Float64` |
| 0.0 + 8.7 | image | julia | `Tuple{typeof(Base.getindex), SimpleVector, Base.UnitRange{Int64}}` |
| 0.7 + 7.9 | session | session | `Tuple{Type{ODECore.FunctionCallback{Base.Vector{Float64}, Float64, Base.Vector{Float64}, C, A, I} where {C<:Callable{Tuple{Base.Vector{Float64}, Float` |
| 0.3 + 8.2 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 2.0 + 6.4 | session | recompile | `Tuple{typeof(Base.setindex!), Base.IdDict{Any, Base.Vector{Any}}, Any, Any}` |
| 0.5 + 7.5 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, Float64, String}` |

