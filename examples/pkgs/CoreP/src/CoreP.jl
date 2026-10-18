"The core of a split-core pair (like StaticArraysCore): the type, and a generic fallback for its arithmetic."
module CoreP
struct P2 <: Number; x::Float64; y::Float64; end
norm1(p::Number) = abs(p)              # an owned function the trait code calls
Base.abs(p::P2) = abs(p.x) + abs(p.y)  # the core's own method
end
