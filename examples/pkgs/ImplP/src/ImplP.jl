"The implementation of a split-core pair (like StaticArrays): Base's and CoreP's functions for CoreP's type. Pirates by the letter."
module ImplP
using CoreP: CoreP, P2
CoreP.norm1(p::P2) = abs(p.x) + abs(p.y) + 0.0   # same value, a more specific method: wins at norm1(::P2)
Base.abs2(p::P2) = p.x^2 + p.y^2
end
