module P
import Fo, Q

# --- probe (U6) ---
g() = Fo.f(Q.make())
const SEEN = g()
const AT_COMPILE = filter(in(Set(["Fo", "P", "Q", "Sp", "Xs", "XsSpExt"])), [String(nameof(m)) for m in Base.loaded_modules_order])
const GENERATING = ccall(:jl_generating_output, Cint, ()) == 1

end
