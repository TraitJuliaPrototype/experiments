using DataFrames, Tables, TraitWorld
table = DataFrame(a = [1, 2], b = [:x, :y])
c = Tables.columns(table)
println(typeof(c), " -> ", Base.infer_return_type(Tables.materializer(table), (typeof(c),)))
r = fully_typed(DataFrame, (typeof(c),))
show(stdout, MIME"text/plain"(), r); println()
