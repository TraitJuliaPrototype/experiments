; Function Signature: step(Core.Dynamic{T.Model}, Float64)
; Function Attrs: noinline
define double @julia_step_1221(ptr nocapture noundef nonnull readonly align 8 dereferenceable(8) %"m::Dynamic", double %"u::Float64") local_unnamed_addr #0 {
top:
  %0 = call double @j_rate_1224(ptr nocapture nonnull readonly %"m::Dynamic", double %"u::Float64")
  %1 = fmul double %0, 1.000000e-09
  %2 = fadd double %"u::Float64", %1
  ret double %2
}
