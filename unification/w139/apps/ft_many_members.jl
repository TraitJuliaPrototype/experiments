# W-142 (compiler C-87): a trait with more than 64 members; a value known only by the trait.
using TraitWorld
@trait Numbered begin
    num(s::Numbered)::Int
end
for i in 1:70
    S = Symbol(:N, i)
    @eval struct $S end
    @eval num(::$S) = $i
    @eval @implement Numbered $S
end
function (@main)(args::Vector{String})::Cint
    xs = Numbered[N1(), N70(), N33()]
    t = 0
    for x in xs
        t += num(x)
    end
    println(Core.stdout, t)
    return 0
end
