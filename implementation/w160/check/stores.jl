# W-160 (d): the other sites where code generation tests a known member against its trait when it runs:
# a store into storage typed by the trait (a vector's element, a mutable struct's field), a typeassert,
# and the box's constructor. Prints whether each site's IR holds a run-time membership query.
using TraitWorld, InteractiveUtils
module T
using TraitWorld
@trait_module
@trait Shape begin
    area(s::Shape)::Float64
end
struct Circle; r::Float64; end
area(c::Circle) = 3.0 * c.r^2
@implement Shape Circle
mutable struct Holder; s::Shape; end
end
using .T: Shape, Circle, Holder
store_vec!(v::Vector{Shape}, c::Circle) = (v[1] = c; nothing)
push_vec!(v::Vector{Shape}, c::Circle) = (push!(v, c); nothing)
store_field!(h::Holder, c::Circle) = (h.s = c; nothing)
make_holder(c::Circle) = Holder(c)
asserted(c::Circle) = (c::Shape; nothing)
converted(c::Circle) = convert(Shape, c)
boxed(c::Circle) = Dynamic{Shape}(c)
ir(f, tt) = sprint(io -> code_llvm(io, f, tt; debuginfo = :none))
q(s) = occursin("ijl_isa", s) || occursin("ijl_subtype", s) || occursin("ijl_typeassert", s)
for (name, f, tt) in (("store into Vector{Shape}", store_vec!, (Vector{Shape}, Circle)),
                      ("push! into Vector{Shape}", push_vec!, (Vector{Shape}, Circle)),
                      ("setfield! of a field ::Shape", store_field!, (Holder, Circle)),
                      ("a struct with a field ::Shape", make_holder, (Circle,)),
                      ("typeassert c::Shape", asserted, (Circle,)),
                      ("convert(Shape, c)", converted, (Circle,)),
                      ("Dynamic{Shape}(c)", boxed, (Circle,)))
    s = ir(f, tt)
    println(rpad(name, 32), q(s) ? "a run-time membership query" : "no run-time query")
end
const N = 10^7
v = Shape[Circle(1.0)]; h = Holder(Circle(1.0)); c = Circle(2.0)
loop1(v, c, n) = (for _ in 1:n; store_vec!(v, c); end; nothing)
loop2(h, c, n) = (for _ in 1:n; store_field!(h, c); end; nothing)
loop1(v, c, 10); loop2(h, c, 10)
println("store into Vector{Shape}: ", round(minimum(@elapsed(loop1(v, c, N)) for _ in 1:5) / N * 1e9; digits = 2), " ns")
println("setfield! of a field ::Shape: ", round(minimum(@elapsed(loop2(h, c, N)) for _ in 1:5) / N * 1e9; digits = 2), " ns")
