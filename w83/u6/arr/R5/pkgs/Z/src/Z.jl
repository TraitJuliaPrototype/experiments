module Z
import P

# --- probe (U6) ---
g() = P.h(P.mk())
const SEEN = g()
const AT_COMPILE = filter(in(Set(["Fo", "P", "Q", "Sp", "Xs", "XsSpExt", "Z"])), [String(nameof(m)) for m in Base.loaded_modules_order])
const GENERATING = ccall(:jl_generating_output, Cint, ()) == 1

end
