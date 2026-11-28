
# a method's interferences, listed when it was inserted, are asked again in the query's world where a set
# occurs: a set that joins another after both methods were defined orders them
@set IfX
@set IfY
struct IfS end
member!(IfY, IfS)
ifg(::Any) = :Any
ifg(::IfX) = :X
ifg(::IfY) = :Y
member!(IfX, IfY)
Base.@nospecializeinfer ifq(@nospecialize(x::IfX)) = ifg(x)

@testset "a listed interference is asked again in the query's world" begin
    ms = [m.method.sig for m in Base._methods_by_ftype(Tuple{typeof(ifg), IfX}, -1, world())]
    @test Tuple{typeof(ifg), IfY} in ms
    @test ifq(IfS()) === :Y
    @test which(ifg, Tuple{IfS}).sig == Tuple{typeof(ifg), IfY}
end
