`frames-up-H-trace-2.trace`: 97 compiles dispatched, 10052 ms (the harness's 27, 1008 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 1800 |
| recompile | 23 | 6258 |
| own image | 26 | 927 |
| composition | 2 | 841 |
| julia | 43 | 225 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 2780.5 | recompile | `Tuple{Main.var"#21#22"}` |
| 1792.5 | session | `Tuple{Main.var"#21#22"}` |
| 830.6 | composition | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 802.5 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 794.8 | recompile | `Tuple{typeof(CSV._parse), Array{UInt8, 1}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Union` |
| 749.7 | recompile | `Tuple{typeof(CSV._parse), Array{UInt8, 1}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Union` |
| 225.4 | recompile | `Tuple{DataFrames.var"#_combine##4#_combine##5"{DataFrames.GroupedDataFrame{DataFrames.DataFrame}, Bool, Bool, Bool, DataFrames.DataFrame, Base.Dict{Symbol, Tuple{Bool, In` |
| 224.6 | recompile | `Tuple{DataFrames.var"#_combine##4#_combine##5"{DataFrames.GroupedDataFrame{DataFrames.DataFrame}, Bool, Bool, Bool, DataFrames.DataFrame, Base.Dict{Symbol, Tuple{Bool, In` |
| 210.9 | own image | `Tuple{typeof(Core.kwcall), NamedTuple{(:parallel, :ntasks, :maxproblems, :validate), Tuple{Bool, Nothing, Int64, Bool}}, typeof(CSV._prepareindexed), String}` |
| 157.9 | recompile | `Tuple{typeof(Base.repr), Tuple{DataFrames.DataFrame, DataFrames.DataFrame, DataFrames.DataFrame}}` |
| 155.3 | own image | `Tuple{typeof(Base.repr), Tuple{DataFrames.DataFrame, DataFrames.DataFrame, DataFrames.DataFrame}}` |
| 113.3 | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Array{Float64, 1}}, Tuple{Nothing}, Tuple{Nothing}, Base.Val{false}, Array{Int64, 1}, Bool, Bool, Bool}` |
| 107.4 | recompile | `Tuple{DataFrames.var"#_describe##12#_describe##13"{Array{Symbol, 1}, Array{Any, 1}}, Array{Float64, 1}}` |
| 97.3 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:alignment, :alignment_anchor_fallback, :alignment_anchor_regex, :column_label_alignment, :column_labels, :compact_printing, :conti` |
| 77.4 | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Array{Float64, 1}}, Base.Val{false}, Array{Int64, 1}, Bool, Nothing, Bool}` |
| 74.4 | own image | `Tuple{typeof(DataFrames._sortperm), DataFrames.DataFrame, Base.Sort.MergeSortAlg, Base.Order.Perm{Base.Order.ForwardOrdering, Array{Float64, 1}}}` |
| 66.4 | own image | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Unitful.FreeUnits{(Unitful.Unit{:Degree, Unitful.Dimensions{()}()}(tens=0, power=Base.Ration` |
| 65.2 | recompile | `Tuple{typeof(DataFrames.normalize_selection), DataFrames.Index, Pair{var"#s120", var"#s119"} where var"#s119"<:Union{Function, Type} where var"#s120"<:Union{AbstractStrin` |
| 54.2 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:parallel, :ntasks, :maxproblems, :validate), Tuple{Bool, Nothing, Int64, Bool}}, typeof(CSV._prepareindexed), String}` |
| 38.4 | own image | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Tuple{Unitful.Unit{:Degree, Unitful.Dimensions{()}()}}}` |

`frames-up-H-trace-2.census`: 1697 instances inferred or given machine code in the process (the harness's 38 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | recompile | 673 | 1746 | 3926 |
| inferred in the session | own image | 531 | 1063 | 2606 |
| inferred in the session | composition | 48 | 120 | 465 |
| inferred in the session | julia | 422 | 196 | 202 |
| image, no machine code | julia | 20 | 0 | 62 |
| inferred in the session | session | 1 | 1 | 11 |
| image, no machine code | own image | 2 | 0 | 7 |
| all | | 1697 | 3126 | 7279 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 128.9 + 537.1 | session | recompile | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 92.0 + 536.1 | session | own image | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 77.9 + 344.0 | session | own image | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 33.1 + 340.8 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 27.1 + 330.6 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 26.4 + 328.6 | session | own image | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 39.6 + 230.2 | session | composition | `Tuple{CSV.var"##_executescanplan#323", CSV.ProblemLog, Int64, Symbol, String, typeof(CSV._executescanplan), CSV.IndexedSource, Tables.Scan}` |
| 24.6 + 228.6 | session | recompile | `Tuple{CSV.var"##_executescanplan#323", CSV.ProblemLog, Int64, Symbol, String, typeof(CSV._executescanplan), CSV.IndexedSource, Tables.Scan}` |
| 222.5 + 0.0 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 202.2 + 16.7 | session | recompile | `Tuple{CSV.var"##_parseprepared#115", Bool, Nothing, Bool, Int64, Nothing, Base.Vector{Bool}, Bool, typeof(CSV._parseprepared), CSV.IndexedSource, CSV.` |
| 10.2 + 182.4 | session | recompile | `Tuple{typeof(CSV._streampredicate), CSV.IndexedSource, CSV.ColumnPlan, Tables.BoundScan, Int64, Int64, Int64}` |
| 10.9 + 181.5 | session | composition | `Tuple{typeof(CSV._streampredicate), CSV.IndexedSource, CSV.ColumnPlan, Tables.BoundScan, Int64, Int64, Int64}` |

