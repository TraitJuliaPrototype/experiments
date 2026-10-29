module P
import Fo, Sp, Xs

# --- probe (U6) ---
g() = Fo.f(Sp.Ty())
const SEEN = g()
const AT_COMPILE = filter(in(Set(["Fo", "FoXsExt", "P", "Sp", "Xs"])), [String(nameof(m)) for m in Base.loaded_modules_order])
const GENERATING = ccall(:jl_generating_output, Cint, ()) == 1

end
