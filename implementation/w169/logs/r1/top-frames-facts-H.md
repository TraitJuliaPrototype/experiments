`frames-facts-H-trace-2.trace`: 96 compiles dispatched, 3499 ms (the harness's 21, 833 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 26 |
| recompile | 8 | 1516 |
| own image | 26 | 780 |
| composition | 4 | 940 |
| julia | 55 | 237 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 934.7 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 895.8 | composition | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 390.9 | recompile | `Tuple{typeof(CSV._parse), Array{UInt8, 1}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Union` |
| 263.6 | own image | `Tuple{typeof(Core.kwcall), NamedTuple{(:parallel, :ntasks, :maxproblems, :validate), Tuple{Bool, Nothing, Int64, Bool}}, typeof(CSV._prepareindexed), String}` |
| 116.7 | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Array{Float64, 1}}, Tuple{Nothing}, Tuple{Nothing}, Base.Val{false}, Array{Int64, 1}, Bool, Bool, Bool}` |
| 100.5 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:alignment, :alignment_anchor_fallback, :alignment_anchor_regex, :column_label_alignment, :column_labels, :compact_printing, :conti` |
| 82.8 | own image | `Tuple{DataFrames.var"##show#860", Bool, Bool, Symbol, Bool, Bool, Int64, Base.Pairs{Symbol, Union{}, Nothing, NamedTuple{(), Tuple{}}}, typeof(Base.show), Base.IOContext{` |
| 75.4 | own image | `Tuple{typeof(DataFrames._sortperm), DataFrames.DataFrame, Base.Sort.MergeSortAlg, Base.Order.Perm{Base.Order.ForwardOrdering, Array{Float64, 1}}}` |
| 58.9 | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Array{Float64, 1}}, Base.Val{false}, Array{Int64, 1}, Bool, Nothing, Bool}` |
| 33.9 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:parallel, :ntasks, :maxproblems, :validate), Tuple{Bool, Nothing, Int64, Bool}}, typeof(CSV._prepareindexed), String}` |
| 31.6 | recompile | `Tuple{typeof(Base._atexit), Int32}` |
| 30.2 | composition | `Tuple{Type{DataFrames.DataFrame}, Tables.CopiedColumns{CSV.File}}` |
| 29.4 | own image | `Tuple{typeof(Base.repr), Tuple{DataFrames.DataFrame, DataFrames.DataFrame, DataFrames.DataFrame}}` |
| 19.4 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 19.4 | own image | `Tuple{typeof(Base.get!), DataFrames.var"#batch_compacttype##2#batch_compacttype##3"{Type{Symbol}, Int64}, Base.Dict{Any, String}, Type{Symbol}}` |
| 17.9 | own image | `Tuple{typeof(Base.get!), DataFrames.var"#batch_compacttype##2#batch_compacttype##3"{Type{typeof(DataType)}, Int64}, Base.Dict{Any, String}, Type{typeof(DataType)}}` |
| 17.8 | session | `Tuple{Main.var"#21#22"}` |
| 16.0 | own image | `Tuple{typeof(Base.first), DataFrames.DataFrame, Int64}` |
| 13.1 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 12.7 | own image | `Tuple{Base.var"#647#648"{typeof(AdaptiveArrayPools._safe_auto_manage_sweep!), Base.Timer}}` |

`frames-facts-H-trace-2.census`: 480 instances inferred or given machine code in the process (the harness's 26 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | recompile | 60 | 647 | 1210 |
| inferred in the session | own image | 149 | 409 | 952 |
| inferred in the session | julia | 212 | 90 | 184 |
| image, no machine code | julia | 28 | 0 | 83 |
| inferred in the session | composition | 28 | 10 | 49 |
| inferred in the session | session | 1 | 2 | 7 |
| image, no machine code | own image | 2 | 0 | 8 |
| all | | 480 | 1157 | 2494 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 258.8 + 535.6 | session | recompile | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 94.6 + 537.1 | session | own image | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 55.2 + 320.6 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 211.1 + 0.0 | session | recompile | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions}` |
| 87.5 + 13.0 | session | own image | `Tuple{CSV.var"##resolvesource#102", Bool, Bool, Nothing, typeof(CSV.resolvesource), CSV.LocalFile}` |
| 51.2 + 31.1 | session | recompile | `Tuple{typeof(Base.find_terminfo_file), String}` |
| 6.8 + 75.4 | session | recompile | `Tuple{typeof(PrettyTables._pretty_table), IO, Any, Symbol, Any, Bool, Bool, Bool, Symbol, String, String, String, String, Union{Nothing, Base.Abstract` |
| 5.1 + 69.9 | session | own image | `Tuple{DataFrames.var"##_show#859", Bool, Bool, Symbol, Bool, Bool, Nothing, Bool, Int64, Base.Pairs{Symbol, Union{}, Nothing, @NamedTuple{}}, typeof(D` |
| 4.4 + 61.5 | session | recompile | `Tuple{typeof(PrettyTables._text__render_table), PrettyTables.TableData, PrettyTables.RenderContext, Union{Base.Val{:print}, Base.Val{:show}}, Bool, Ba` |
| 49.0 + 0.0 | session | own image | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions}` |
| 29.5 + 6.9 | session | own image | `Tuple{typeof(DataFrames.row_group_slots!), Tuple{Base.Vector{Float64}}, Base.Val{false}, Base.Vector{Int64}, Bool, Nothing, Bool}` |
| 6.8 + 28.3 | session | own image | `Tuple{typeof(DataFrames.hashrows_col!), Base.Vector{UInt64}, Base.Vector{Bool}, Base.Vector{Float64}, Nothing, Bool}` |

