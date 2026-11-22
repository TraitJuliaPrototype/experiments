`odecb-plain-H-trace-2.trace`: 34 compiles dispatched, 280 ms (the harness's 17, 770 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 8 | 135 |
| recompile | 0 | 0 |
| own image | 4 | 14 |
| composition | 0 | 0 |
| julia | 22 | 131 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 109.3 | session | `Tuple{typeof(Main.main), Array{String, 1}}` |
| 29.8 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 16.5 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 11.1 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 7.8 | own image | `Tuple{typeof(PlainODE.event_time), PlainODE.ContinuousCallback, PlainODE.Tsit5Integrator{Float64, Array{Float64, 1}}, Array{Float64, 1}, Float64, Float64, Float64}` |
| 6.4 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofVararg}` |
| 5.8 | session | `Tuple{Type{FunctionWrappers.FunctionWrapper{Nothing, Tuple{Array{Float64, 1}, Array{Float64, 1}, Array{Float64, 1}, Float64}}}, typeof(Main.lorenz!)}` |
| 5.6 | julia | `Tuple{typeof(Base.println), String, String, Int64, Vararg{Any}}` |
| 5.3 | session | `Tuple{typeof(Base.getproperty), Base.Order.By{Main.var"#18#19", Base.Order.ForwardOrdering}, Symbol}` |
| 4.8 | julia | `Tuple{typeof(Base._array_for), Type{String}, Array{Base.SubString{String}, 1}, Base.HasShape{1}}` |
| 4.3 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:context,), Tuple{Pair{Symbol, Module}}}, typeof(Base.sprint), Function, Type}` |
| 4.2 | julia | `Tuple{typeof(Base.iterate), Array{Base.SubString{String}, 1}}` |
| 4.0 | julia | `Tuple{typeof(Base.print), Base.IOStream, Int64}` |
| 3.7 | julia | `Tuple{typeof(Core.kwcall), NamedTuple{(:label,), Tuple{String}}, typeof(Core.invokelatest), Function, String}` |
| 3.7 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Core.TypeofBottom}` |
| 3.7 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Int64}` |
| 3.4 | julia | `Tuple{Type{NamedTuple{(:sigdigits,), T} where T<:Tuple}, Tuple{Int64}}` |
| 3.2 | own image | `Tuple{Type{NamedTuple{(:callback, :reltol, :abstol), T} where T<:Tuple}, Tuple{Tuple{PlainODE.DiscreteCallback, PlainODE.ContinuousCallback}, Float64, Float64}}` |
| 3.2 | session | `Tuple{typeof(Main.cross_c), Array{Float64, 1}, Float64, PlainODE.Tsit5Integrator{Float64, Array{Float64, 1}}}` |

`odecb-plain-H-trace-2.census`: 117 instances inferred or given machine code in the process (the harness's 22 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | julia | 66 | 46 | 69 |
| inferred in the session | session | 28 | 48 | 28 |
| inferred in the session | own image | 18 | 5 | 21 |
| image, no machine code | julia | 5 | 0 | 15 |
| all | | 117 | 98 | 133 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 19.7 + 7.8 | session | session | `Tuple{typeof(Main.main), Base.Vector{String}}` |
| 19.0 + 5.3 | session | session | `Tuple{Type{FunctionWrappers.FunctionWrapper{Nothing, Tuple{Base.Vector{Float64}, Base.Vector{Float64}, Base.Vector{Float64}, Float64}}}, typeof(Main.l` |
| 15.1 + 0.0 | session | julia | `Tuple{typeof(Base.lastindex), Base.Vector{Base.Vector{Float64}}}` |
| 14.9 + 0.0 | session | julia | `Tuple{typeof(Base.eachindex), Base.IndexLinear, Base.Vector{Base.Vector{Float64}}}` |
| 0.6 + 9.5 | session | own image | `Tuple{PlainODE.var"##solve#12", Tuple{PlainODE.DiscreteCallback, PlainODE.ContinuousCallback}, Base.Pairs{Symbol, Float64, Nothing, @NamedTuple{reltol` |
| 0.4 + 8.8 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 0.3 + 8.4 | session | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, String}` |
| 0.5 + 7.6 | session | julia | `Tuple{typeof(Base.print), CoreSTDOUT, String, Float64, String}` |
| 0.5 + 7.2 | session | julia | `Tuple{typeof(Base.hidigit), Float64, Int64}` |
| 1.4 + 6.0 | session | own image | `Tuple{typeof(PlainODE.event_time), PlainODE.ContinuousCallback, PlainODE.Tsit5Integrator{Float64, Base.Vector{Float64}}, Base.Vector{Float64}, Float64` |
| 1.3 + 5.2 | session | session | `Tuple{FunctionWrappers.CallWrapper{Nothing}, typeof(Main.lorenz!), Base.Vector{Float64}, Base.Vector{Float64}, Base.Vector{Float64}, Float64}` |
| 1.1 + 4.5 | session | julia | `Tuple{typeof(Base.show), CoreSTDOUT, Float64, Bool, Bool}` |

