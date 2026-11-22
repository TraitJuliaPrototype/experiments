`frames-forks-H-trace-2.trace`: 75 compiles dispatched, 2780 ms (the harness's 21, 854 ms, left out)

| class | compiles | ms |
|---|---|---|
| session | 3 | 21 |
| recompile | 8 | 2386 |
| own image | 15 | 113 |
| composition | 0 | 0 |
| julia | 49 | 260 |

The 20 largest:

| ms | class | signature |
|---|---|---|
| 923.7 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:is_stdout, :alignment_anchor_fallback, :alignment_anchor_regex, :fit_table_in_display_horizontally, :fit_table_in_display_vertical` |
| 655.8 | recompile | `Tuple{Main.var"#21#22"}` |
| 643.3 | recompile | `Tuple{typeof(CSV._parse), Array{UInt8, 1}, CSV.Dialect, CSV.ValueOpts, Symbol, Nothing, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Nothing, Nothing, Array{Symbol, 1},` |
| 103.5 | recompile | `Tuple{typeof(Core.kwcall), NamedTuple{(:alignment, :alignment_anchor_fallback, :alignment_anchor_regex, :column_label_alignment, :column_labels, :compact_printing, :conti` |
| 34.2 | julia | `Tuple{typeof(Base.println), String, Float64}` |
| 31.1 | recompile | `Tuple{typeof(Base._atexit), Int32}` |
| 22.8 | own image | `Tuple{typeof(Base.first), DataFrames.DataFrame, Int64}` |
| 21.4 | own image | `Tuple{typeof(Base.repr), Tuple{DataFrames.DataFrame, DataFrames.DataFrame, DataFrames.DataFrame}}` |
| 20.8 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Tuple{Int64}}` |
| 17.7 | recompile | `Tuple{typeof(PrettyTables._preprocess_data), Any}` |
| 16.9 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, Float64, Vararg{Any}}` |
| 13.4 | session | `Tuple{Main.var"#21#22"}` |
| 12.5 | own image | `Tuple{Base.var"#647#648"{typeof(AdaptiveArrayPools._safe_auto_manage_sweep!), Base.Timer}}` |
| 12.0 | julia | `Tuple{typeof(Base.show), Base.IOContext{Base.GenericIOBuffer{Memory{UInt8}}}, Tuple{}}` |
| 11.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, Float64}` |
| 11.4 | own image | `Tuple{typeof(FreeTypeAbstraction.ft_done)}` |
| 10.8 | own image | `Tuple{typeof(AdaptiveArrayPools.disable_auto_manage!)}` |
| 9.7 | julia | `Tuple{typeof(Base.print), Base.IOStream, String, String, Vararg{Any}}` |
| 9.4 | julia | `Tuple{typeof(Base.getindex), Core.SimpleVector, Base.UnitRange{Int64}}` |
| 7.0 | recompile | `Tuple{typeof(Base.println), String, Float64}` |

`frames-forks-H-trace-2.census`: 589 instances inferred or given machine code in the process (the harness's 33 left out)

| where the inferred code came from | class | instances | inference (self, ms) | code generation (ms) |
|---|---|---|---|---|
| inferred in the session | recompile | 63 | 1170 | 1584 |
| inferred in the session | julia | 351 | 250 | 71 |
| inferred in the session | own image | 125 | 41 | 55 |
| image, no machine code | julia | 27 | 0 | 83 |
| inferred in the session | session | 1 | 4 | 6 |
| image, no machine code | own image | 3 | 0 | 9 |
| inferred in the session | composition | 19 | 8 | 0 |
| all | | 589 | 1472 | 1810 |

The census's 12 largest (inference + code generation of the instance alone):

| ms (inf + gen) | where | class | signature |
|---|---|---|---|
| 253.7 + 529.8 | session | recompile | `Tuple{typeof(PrettyTables._text__print_table_core), PrettyTables.PrintingSpec, PrettyTables.TextPrintOptions, Bool}` |
| 34.5 + 290.3 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Nothing, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Nothing, Not` |
| 24.6 + 273.9 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Nothing, Int64, Bool, Int64, Int64, Symbol, Bool, Bool, Nothing, Not` |
| 272.7 + 6.2 | session | recompile | `Tuple{Main.var"#21#22"}` |
| 177.9 + 60.4 | session | recompile | `Tuple{typeof(PrettyTables._text__render_table), PrettyTables.TableData, PrettyTables.RenderContext, Union{Base.Val{:print}, Base.Val{:show}}, Bool, Ba` |
| 168.0 + 0.0 | session | recompile | `Tuple{typeof(CSV._parse), Base.Vector{UInt8}, CSV.Dialect, CSV.ValueOpts, Symbol, Union{Nothing, Base.Dict{Type, Type}}, Int64, Bool, Int64, Int64, Sy` |
| 6.4 + 114.6 | session | recompile | `Tuple{CSV.var"##_transposedfile#152", Nothing, Bool, Bool, Type, Symbol, Int64, Bool, Nothing, Nothing, Char, Bool, Nothing, Bool, Bool, Nothing, Bool` |
| 101.4 + 0.0 | session | julia | `Tuple{typeof(Base.__cat), Base.Vector{Int64}, Tuple{Int64}, Tuple{Bool}, Int64, Base.Vector{Int64}}` |
| 6.6 + 78.5 | session | recompile | `Tuple{typeof(PrettyTables._pretty_table), IO, Any, Symbol, Any, Bool, Bool, Bool, Symbol, String, String, String, String, Union{Nothing, Base.Abstract` |
| 3.6 + 63.4 | session | recompile | `Tuple{typeof(CSV._filefromprepared), CSV.IndexedSource, String, Nothing, Nothing, Nothing, Bool, Bool, Base.Val{DataStrings.DataString}, Symbol, Int64` |
| 30.1 + 0.0 | session | recompile | `Tuple{CSV.var"##_transposedfile#152", Nothing, Bool, Bool, DataType, Symbol, Int64, Bool, Nothing, Nothing, Char, Bool, Nothing, Bool, Bool, Nothing, ` |
| 2.2 + 27.3 | session | recompile | `Tuple{CSV.var"##_prepareindexed#115", Base.Pairs{Symbol, Union{Nothing, Integer}, Nothing, @NamedTuple{parallel::Bool, ntasks::Nothing, maxproblems::I` |

