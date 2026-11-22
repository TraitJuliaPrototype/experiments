# W-158 seventh part: a trait and a member whose method calls PImgQ.h, checked while this image is built
# (p-probes/ops.jl, case "image")
module PImg
using TraitWorld, PImgQ
@trait IX begin
    iop(x::IX)::Float64
end
struct IA; x::Int; end
iop(a::IA) = PImgQ.h(a.x)
@implement IX IA
end
