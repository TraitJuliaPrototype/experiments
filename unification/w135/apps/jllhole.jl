# E-361: plain Julia's hole in a JLL package's `__init__` (JLLWrappers: `unique!` of the library paths
# calls `issorted` with an ordering it does not infer). A program with a JLL of several library paths
# needs this entry point, in trait form and in plain form alike. JLLHOLE=0 builds without it.
get(ENV, "JLLHOLE", "1") == "1" &&
    Base.Experimental.entrypoint(Tuple{typeof(issorted), Vector{String}, Base.Order.ReverseOrdering{Base.Order.ForwardOrdering}})
