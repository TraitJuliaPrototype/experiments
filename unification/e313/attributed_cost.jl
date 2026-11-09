# E-313: the cost of a call through `Core.attributed_call` (compiler §6.9) against a plain dynamic call
# (`jl_apply_generic`), per call, at a value whose type the caller does not know. A trait argument
# `Compiled` (bits 1, 0) and `Dynamic` (bits 1 | 1 << 32).
#   julia --project=experiments/unification experiments/unification/e313/attributed_cost.jl
using Traits
@trait Q
struct A; x::Int; end
struct B; x::Int; end
@implement Q A
@implement Q B
h(q::Q) = getfield(q, :x)
const xs = Any[A(1), B(2), A(3), B(4)]
function plain(xs, n)
    s = 0
    for _ in 1:n, x in xs
        s += h(x)::Int
    end
    s
end
function attributed(xs, n, bits)
    s = 0
    for _ in 1:n, x in xs
        s += Core.attributed_call(bits, h, x)::Int
    end
    s
end
const N = 250_000
plain(xs, 10); attributed(xs, 10, 1); attributed(xs, 10, 1 | (1 << 32))
for r in 1:3
    tp = @elapsed plain(xs, N)
    tc = @elapsed attributed(xs, N, 1)
    td = @elapsed attributed(xs, N, 1 | (1 << 32))
    println("ns per call: plain ", round(tp / (4N) * 1e9; digits = 1), "  attributed Compiled ", round(tc / (4N) * 1e9; digits = 1),
            "  attributed Dynamic ", round(td / (4N) * 1e9; digits = 1))
end
