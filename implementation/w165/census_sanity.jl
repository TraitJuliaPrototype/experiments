# The census's control: two pairs it must find (W-165)
apply165(f::Core.Callable{Tuple{Int}, Int}, x) = :int
apply165(f::Core.Callable{Tuple{String}, <:AbstractString}, x) = :string
both165(f::Core.All{Tuple{Core.Callable{Tuple{Int}, Int}, Core.Callable{Tuple{Float64}, Float64}}}) = 1
both165(f::Core.Callable{Tuple{Int}, Int}) = 2
include("census.jl")
