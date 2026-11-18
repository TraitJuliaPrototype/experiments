# Bounded methods of one shape, one with keywords and one without, in both orders (lowering L-48).
using TraitWorld
@trait_module module M130
using TraitWorld
export TA, TB, A1, B1, ta, tb
@trait TA begin
    ta(x::Self)::Int
end
@trait TB <: TA begin
    tb(x::Self)::Int
end
struct A1; s::Int; end
struct B1; s::Int; end
@implement TA A1 begin
    ta(x::A1) = x.s
end
@implement TA B1 begin
    ta(x::B1) = x.s
end
@implement TB B1 begin
    tb(x::B1) = x.s
end
end
using .M130
for (name, a, b) in ((:f, :(f(x::TA) = ("A", ta(x))), :(f(x::TB; k = 1) = ("B", tb(x), k))),
                     (:g, :(g(x::TB; k = 1) = ("B", tb(x), k)), :(g(x::TA) = ("A", ta(x)))))
    mn = Symbol(:Mixed, name)
    r = try
        Core.eval(Main, :(@trait_module module $mn
            using TraitWorld, ..M130
            $a
            $b
            $name(x; k = 0) = ("untyped", x, k)
            end))
        nothing
    catch e
        e
    end
    if r !== nothing
        println(name, ": refused at definition: ", first(split(sprint(showerror, r isa LoadError ? r.error : r), '\n')))
        continue
    end
    M = getfield(Main, mn); fn = getfield(M, name)
    for (s, c) in (("A1", () -> fn(A1(1))), ("B1", () -> fn(B1(2))), ("B1; k = 5", () -> fn(B1(2); k = 5)),
                   ("A1; k = 5", () -> fn(A1(1); k = 5)), ("7; k = 5", () -> fn(7; k = 5)), ("7", () -> fn(7)))
        v = try c() catch e; "ERROR " * first(split(sprint(showerror, e), '\n')) end
        println(name, "(", s, ") => ", v)
    end
end
