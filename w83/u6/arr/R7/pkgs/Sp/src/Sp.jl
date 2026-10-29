module Sp
import Fo
struct Ty end

# --- probe (U6) ---
g() = Fo.f(Ty())
const SEEN = g()
const AT_COMPILE = filter(in(Set(["Fo", "Sp", "SpXsExt", "Xs"])), [String(nameof(m)) for m in Base.loaded_modules_order])
const GENERATING = ccall(:jl_generating_output, Cint, ()) == 1

end
