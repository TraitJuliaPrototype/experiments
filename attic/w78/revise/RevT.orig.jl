@trait_module module RevT
using TraitWorld
export RVals, rvals, rsq
@trait RVals begin
    rvals(v::RVals)::Vector{Float64}
end
@implement RVals Vector{Float64} begin
    rvals(v) = v
end
rsq(v::RVals) = (s = 0.0; for x in rvals(v); s += abs2(x); end; s)
end
