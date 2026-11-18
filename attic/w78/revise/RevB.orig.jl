module RevB
using TraitWorld
export RVals, rvals, rsq
@trait_module begin
@trait RVals begin
    rvals(v::RVals)::Vector{Float64}
end
@implement RVals Vector{Float64} begin
    rvals(v) = v
end
rsq(v::RVals) = (s = 0.0; for x in rvals(v); s += x; end; s)
end
end
