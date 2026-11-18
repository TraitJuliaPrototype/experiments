# E-358: generate the packages. julia gen.jl <dir> [n=20]
# <dir>/trait: CompCore (a trait module) and CompM01..n. <dir>/plain: PCore and PM01..n, the same as plain Julia.
# The packages have no Project.toml: they are found through JULIA_LOAD_PATH (see run.sh).
const dir = ARGS[1]; const n = length(ARGS) > 1 ? parse(Int, ARGS[2]) : 20
pad(i) = lpad(i, 2, '0')
function put(root, name, src)
    mkpath(joinpath(root, name, "src")); write(joinpath(root, name, "src", name * ".jl"), src)
end
generic = """
total(v) = (t = 0.0; for s in v; t += area(s); end; t)
step(s, k::Float64) = (t = 0.0; for i in 1:8; t += area(s) * k / i + length(label(s)); end; t)
"""
put(joinpath(dir, "trait"), "CompCore", """
module CompCore
using TraitWorld
@trait_module
export Shape, area, label, total, work
"A shape: its area and a label."
@trait Shape begin
    area(s::Shape)::Float64
    label(s::Shape)::String
end
total(v::Vector{Shape}) = (t = 0.0; for s in v; t += area(s); end; t)
step(s::Shape, k::Float64) = (t = 0.0; for i in 1:8; t += area(s) * k / i + length(label(s)); end; t)
"Each member's step, compiled for the member's type."
work(v::Vector{Shape}) = (t = total(v); for s in v; t += step(compiled_for(s), 2.0); end; t)
end
""")
put(joinpath(dir, "plain"), "PCore", """
module PCore
export Shape, area, label, total, work
abstract type Shape end
function area end
function label end
total(v::Vector{Shape}) = (t = 0.0; for s in v; t += area(s); end; t)
step(s::Shape, k::Float64) = (t = 0.0; for i in 1:8; t += area(s) * k / i + length(label(s)); end; t)
work(v::Vector{Shape}) = (t = total(v); for s in v; t += step(s, 2.0); end; t)
end
""")
for i in 1:n
    p = pad(i)
    body = """
    own(s::M, m::Int) = (t = 0.0; for j in 1:m; t += area(s) * j; end; t + length(label(s)))
    make() = M($(i).0, $(i + 1).5)
    # the image's work
    work(Shape[make()]); own(make(), 3)
    """
    put(joinpath(dir, "trait"), "CompM$p", """
    module CompM$p
    using TraitWorld, CompCore
    @trait_module
    struct M
        a::Float64
        b::Float64
    end
    @implement Shape M begin
        area(s) = s.a * s.b + $i
        label(s) = "m$p"
    end
    $body
    end
    """)
    put(joinpath(dir, "plain"), "PM$p", """
    module PM$p
    using PCore
    import PCore: area, label
    struct M <: Shape
        a::Float64
        b::Float64
    end
    area(s::M) = s.a * s.b + $i
    label(s::M) = "m$p"
    $body
    end
    """)
end
