"An ordinary package (no traits): owns `score` and `weight`, called from trait code in XLib."
module XFun
score(x::Real) = 1.0 * x
weight(x::Real) = 1.0
end
