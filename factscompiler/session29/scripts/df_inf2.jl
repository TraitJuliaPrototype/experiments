using DataFrames, Tables, TraitWorld
table = DataFrame(a = [1, 2], b = [:x, :y])
c = Tables.columns(table)
irt(f, T) = try Base.infer_return_type(f, T) catch e; e end
println("conforms: ", TraitWorld.conforms(typeof(c), DataFrames.TableSource), " ", TraitWorld.conforms(DataFrame, DataFrames.TableSource))
println("fromsource(c): ", irt(DataFrames.fromsource, (typeof(c), Bool)))
println("fromsource(df): ", irt(DataFrames.fromsource, (DataFrame, Bool)))
println("fromcolumns: ", irt(DataFrames.fromcolumns, (typeof(c), Vector{Symbol})))
println("kw DataFrame: ", irt(DataFrame, (typeof(c),)))
println("_copy_all_all_metadata!: ", irt(DataFrames._copy_all_all_metadata!, (DataFrame, typeof(c))))
