`nd-H-trace-1.trace`: 958 compiles dispatched, 37494 ms (the harness's 28, 1005 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 8 | 253 |
| recompile | 28 | 731 |
| own image | 232 | 4902 |
| composition | 506 | 30282 |
| julia | 184 | 1326 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 2844.1 | composition | `Tuple{NDW.var"#17#18"{Float64, NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGraphs.SimpleGraph{Int64}, NetworkDynamics.NetworkLayer{Gra` |
| 1579.3 | own image | `Tuple{NetworkDynamics.var"##extend_knowns_by_formulas!#370", Base.Dict{Symbol, Symbol}, Float64, Base.Set{Symbol}, Bool, Bool, Base.IOStream, typeof(NetworkDynamics.exten` |
| 1213.5 | composition | `Tuple{NDW.var"#17#18"{Float64, NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.Test.GenericGraph{Int64}, NetworkDynamics.NetworkLayer{Graphs.Tes` |
| 1172.4 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Network{NetworkDynamics.SequentialE` |
| 805.5 | composition | `Tuple{typeof(NetworkDynamics.set_callback!), NetworkDynamics.EdgeModel, NetworkDynamics.ContinuousComponentCallback{NetworkDynamics.ComponentCondition{NDW.var"#step_d##0#` |
| 694.9 | composition | `Tuple{GraphMakie.var"#72#73", NetworkLayout.Spring{2, Float64, Random.MersenneTwister}, Graphs.SimpleGraphs.SimpleGraph{Int64}}` |
| 609.7 | composition | `Tuple{NDW.var"#19#20"{NamedTuple{(:s, :fix, :λmax), Tuple{NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Networ` |
| 597.3 | composition | `Tuple{typeof(ForwardDiff.jacobian), NetworkDynamics.var"#h!#833"{Nothing, Array{Float64, 1}, NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.Sim` |
| 595.2 | composition | `Tuple{typeof(ForwardDiff.jacobian), NetworkDynamics.var"#h!#833"{Nothing, Array{Float64, 1}, NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.Tes` |
| 550.9 | own image | `Tuple{NetworkDynamics.var"##normalize_valuedict#417", Symbol, Symbol, Bool, Base.IOStream, typeof(NetworkDynamics.normalize_valuedict), Base.Dict{Symbol, Symbol}, Base.Di` |
| 532.7 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Network{NetworkDynamics.SequentialE` |
| 529.5 | composition | `Tuple{NDW.var"#run_plot##0#run_plot##1"{NamedTuple{(:nw, :d, :model), Tuple{NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGraphs.SimpleG` |
| 402.8 | composition | `Tuple{GraphMakie.var"#98#99"{TraitMakie.OldAPI.Plot{typeof(GraphMakie.graphplot), Tuple{Graphs.SimpleGraphs.SimpleGraph{Int64}}}}, Array{GeometryBasics.Point{2, Float32},` |
| 396.6 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.FilteringProxy{NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Netw` |
| 392.3 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.FilteringProxy{NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Netw` |
| 381.3 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.FilteringProxy{NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Netw` |
| 378.3 | composition | `Tuple{typeof(NDW.digest_f), NamedTuple{(:pos, :colors, :file, :p), Tuple{Array{GeometryBasics.Point{2, Float32}, 1}, Array{Float64, 1}, String, TraitMakie.OldAPI.Plot{typ` |
| 371.5 | composition | `Tuple{NDW.var"#run_plot##2#run_plot##3"{NamedTuple{(:nw, :d, :model), Tuple{NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGraphs.SimpleG` |
| 367.3 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.FilteringProxy{NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Netw` |
| 366.3 | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.NWState{Array{Float64, 1}, NetworkDynamics.NWParameter{Array{Float64, 1}, NetworkDynamics.Network{NetworkDynamics.SequentialE` |

`nd-H-trace-1.census`: 21541 instances inferred or given machine code in the process (the harness's 49 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | composition | 7552 | 6860 | 14875 |
| inferred in the session | own image | 5925 | 3603 | 4389 |
| inferred in the session | session | 1538 | 3247 | 3116 |
| inferred in the session | julia | 6361 | 2652 | 3673 |
| inferred in the session | recompile | 75 | 122 | 397 |
| image, no machine code | julia | 65 | 0 | 214 |
| image, no machine code | own image | 20 | 0 | 69 |
| image, no machine code | composition | 4 | 0 | 10 |
| image, no machine code | recompile | 1 | 0 | 4 |
| all | | 21541 | 16483 | 26748 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 1194.3 + 91.4 | session | session | `Tuple{Main.NDW.var"##step_c#3", Float64, typeof(Main.NDW.step_c), NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGrap` |
| 301.0 + 14.5 | session | composition | `Tuple{typeof(Base.getindex), NetworkDynamics.NWState{Base.Vector{Float64}, NetworkDynamics.NWParameter{Base.Vector{Float64}, NetworkDynamics.Network{N` |
| 206.1 + 90.8 | session | session | `Tuple{Main.NDW.var"##step_c#3", Float64, typeof(Main.NDW.step_c), NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.Test.Gener` |
| 146.4 + 89.2 | session | session | `Tuple{typeof(Main.NDW.step_d), NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGraphs.SimpleGraph{Int64}, NetworkDynam` |
| 198.4 + 14.8 | session | own image | `Tuple{NetworkDynamics.var"##jacobian_eigenvals#848", typeof(LinearAlgebra.eigvals), typeof(NetworkDynamics.jacobian_eigenvals), NetworkDynamics.Networ` |
| 79.0 + 128.1 | session | composition | `Tuple{NetworkDynamics.var"##find_fixpoint#485", Nothing, Float64, Float64, Base.Pairs{Symbol, Union{}, Nothing, @NamedTuple{}}, typeof(NetworkDynamics` |
| 134.8 + 66.5 | session | session | `Tuple{typeof(Main.NDW.step_g), NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGraphs.SimpleGraph{Int64}, NetworkDynam` |
| 40.8 + 152.2 | session | composition | `Tuple{typeof(TraitMakie.OldAPI.plot!), TraitMakie.OldAPI.Plot{typeof(GraphMakie.graphplot), Tuple{Graphs.Test.GenericGraph{Int64}}}}` |
| 32.4 + 149.7 | session | composition | `Tuple{typeof(TraitMakie.OldAPI.plot!), TraitMakie.OldAPI.Plot{typeof(GraphMakie.graphplot), Tuple{Graphs.SimpleGraphs.SimpleGraph{Int64}}}}` |
| 150.6 + 22.4 | session | composition | `Tuple{typeof(ForwardDiff.vector_mode_dual_eval!), NetworkDynamics.var"#h!#833"{Nothing, Base.Vector{Float64}, NetworkDynamics.Network{NetworkDynamics.` |
| 75.4 + 87.7 | session | composition | `Tuple{typeof(SymbolicIndexingInterface.default_values), NetworkDynamics.Network{NetworkDynamics.SequentialExecution{true}, Graphs.SimpleGraphs.SimpleG` |
| 99.4 + 58.4 | session | session | `Tuple{typeof(NetworkDynamics.assert_cb_compat), NetworkDynamics.EdgeModel, NetworkDynamics.ContinuousComponentCallback{NetworkDynamics.ComponentCondit` |

