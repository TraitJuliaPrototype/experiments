# W-156, second part: the library's test "trait modules" (TraitWorld test/trait_modules.jl) discriminates. A function
# whose only caller does not know the value's type: in a trait module (`@trait_module`, the library's options) the
# call compiles the instance at the member's type; with Julia's module option `first_seen` (set here directly, as the
# library set it before), at the trait only.
#     julia --project=<TraitWorld> first_seen_discriminates.jl
using TraitWorld
for (name, extra) in ((:P1, :(nothing)), (:P2, :(Base.Experimental.@compiler_options first_seen = true)))
    Core.eval(Main, Expr(:toplevel, :(module $name
        using TraitWorld
        @trait_module
        $extra
        @trait Shape begin
            area(s::Shape)::Float64
        end
        struct Sq; a::Float64; end
        area(s::Sq) = s.a^2
        @implement Shape Sq
        kind2(s::Shape) = s isa Dynamic ? :box : :plain
        unknown2(v::Vector{Any}) = kind2(v[1])
        go() = unknown2(Any[Sq(2.0)])
        specs() = [mi.specTypes for mi in Base.specializations(only(methods(kind2)))]
    end)))
    m = Base.invokelatest(getglobal, Main, name)
    r = Base.invokelatest(getglobal(m, :go))
    specs = Base.invokelatest(getglobal(m, :specs))
    label = name === :P1 ? "@trait_module" : "@trait_module, then Julia's first_seen = true"
    println(rpad(label, 46), ": options ", ccall(:jl_get_module_trait_options, Cint, (Any,), m), "; result ", r,
            "; kind2's instances ", join(string.(specs), ", "), "; the test's assertion (an instance at Sq) ",
            any(s -> s.parameters[2] === m.Sq, specs) ? "holds" : "FAILS")
end
