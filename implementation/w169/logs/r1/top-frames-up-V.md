`frames-up-V-trace-2.trace`: 99 compiles dispatched, 10537 ms (the harness's 27, 993 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 1842 |
| recompile | 22 | 6709 |
| own image | 26 | 913 |
| composition | 2 | 835 |
| julia | 46 | 239 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 3196.0 | recompile | `Tuple{Main.var"#18#19"}` |
| 1833.6 | session | `Tuple{Main.var"#18#19"}` |
| 825.2 | composition | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 810.4 | recompile | `Tuple{typeof(CSV._parse), Array{UInt8, 1}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Union` |
| 801.7 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 762.0 | recompile | `Tuple{typeof(CSV._parse), Array{UInt8, 1}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Union` |
| 227.3 | recompile | `Tuple{DataFrames.var"#_combine##4#_combine##5"{DataFrames.GroupedDataFrame{DataFrames.DataFrame}, Bool, Bool, Bool, DataFrames.DataFrame, Base.Dict{Symbol, Tuple{Bool, In` |
| 226.9 | recompile | `Tuple{DataFrames.var"#_combine##4#_combine##5"{DataFrames.GroupedDataFrame{DataFrames.DataFrame}, Bool, Bool, Bool, DataFrames.DataFrame, Base.Dict{Symbol, Tuple{Bool, In` |
| 204.1 | own image | `Tuple{typeof(Core.kwcall), NamedTuple{(:parallel, :ntasks, :maxproblems, :validate), Tuple{Bool, Nothing, Int64, Bool}}, typeof(CSV._prepareindexed), String}` |
| 158.9 | recompile | `Tuple{typeof(Base.repr), Tuple{DataFrames.DataFrame, DataFrames.DataFrame, DataFrames.DataFrame}}` |
| 149.9 | own image | `Tuple{typeof(Base.repr), Tuple{DataFrames.DataFrame, DataFrames.DataFrame, DataFrames.DataFrame}}` |
| 114.8 | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Array{Float64, 1}}, Tuple{Nothing}, Tuple{Nothing}, Base.Val{false}, Array{Int64, 1}, Bool, Bool, Bool}` |
| 109.4 | recompile | `Tuple{DataFrames.var"#_describe##12#_describe##13"{Array{Symbol, 1}, Array{Any, 1}}, Array{Float64, 1}}` |
| 94.9 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:alignment, :alignment_anchor_fallback, :alignment_anchor_regex, :column_label_alignment, :column_labels, :compact_printing, :conti` |
| 78.0 | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Array{Float64, 1}}, Base.Val{false}, Array{Int64, 1}, Bool, Nothing, Bool}` |
| 75.6 | own image | `Tuple{typeof(DataFrames._sortperm), DataFrames.DataFrame, Base.Sort.MergeSortAlg, Base.Order.Perm{Base.Order.ForwardOrdering, Array{Float64, 1}}}` |
| 67.6 | own image | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Unitful.FreeUnits{(Unitful.Unit{:Degree, Unitful.Dimensions{()}()}(tens=0, power=Base.Ration` |
| 65.8 | recompile | `Tuple{typeof(DataFrames.normalize_selection), DataFrames.Index, Pair{var"#s120", var"#s119"} where var"#s119"<:Union{Function, Type} where var"#s120"<:Union{AbstractStrin` |
| 55.6 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:parallel, :ntasks, :maxproblems, :validate), Tuple{Bool, Nothing, Int64, Bool}}, typeof(CSV._prepareindexed), String}` |
| 40.7 | own image | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Tuple{Unitful.Unit{:Degree, Unitful.Dimensions{()}()}}}` |

`frames-up-V-trace-2.census`: 1700 instances inferred or given machine code in the process (the harness's 24 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | recompile | 686 | 1806 | 3977 |
| inferred in the session | own image | 538 | 1040 | 2625 |
| inferred in the session | composition | 48 | 96 | 470 |
| inferred in the session | julia | 403 | 353 | 190 |
| image, no machine code | julia | 22 | 0 | 80 |
| inferred in the session | session | 1 | 56 | 12 |
| image, no machine code | own image | 2 | 0 | 9 |
| all | | 1700 | 3350 | 7362 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 130.6 + 532.2 | session | recompile | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 71.7 + 531.7 | session | own image | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 83.9 + 348.4 | session | own image | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 33.2 + 347.7 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 27.5 + 335.7 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 26.8 + 333.2 | session | own image | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 29.3 + 232.4 | session | recompile | `Tuple{CSV.var"##_executescanplan#323", CSV.ProblemLog, Int64, Symbol, String, typeof(CSV._executescanplan), CSV.IndexedSource, Tables.Scan}` |
| 22.6 + 231.7 | session | composition | `Tuple{CSV.var"##_executescanplan#323", CSV.ProblemLog, Int64, Symbol, String, typeof(CSV._executescanplan), CSV.IndexedSource, Tables.Scan}` |
| 210.7 + 0.0 | session | recompile | `Tuple{typeof(Base.showerror), Base.IOBuffer, MethodError}` |
| 13.0 + 185.2 | session | recompile | `Tuple{typeof(CSV._streampredicate), CSV.IndexedSource, CSV.ColumnPlan, Tables.BoundScan, Int64, Int64, Int64}` |
| 196.4 + 0.0 | session | julia | `Tuple{typeof(Base.unsafe_convert), Type{Ptr{T}}, SparseArrays.CHOLMOD.Dense} where T<:Union{SparseArrays.LibSuiteSparse.cholmod_dense_struct, SparseAr` |
| 10.5 + 184.6 | session | composition | `Tuple{typeof(CSV._streampredicate), CSV.IndexedSource, CSV.ColumnPlan, Tables.BoundScan, Int64, Int64, Int64}` |

