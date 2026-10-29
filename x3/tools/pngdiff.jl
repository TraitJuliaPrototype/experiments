# Two PNGs compared pixel by pixel (Cairo): the share of pixels that differ and the largest channel difference.
#     julia --project=TraitMakie experiments/x3/tools/pngdiff.jl a.png b.png
using Cairo
# the image surface's own data, by its stride (as TraitMakie's test suite reads it). E-227 found that painting the PNG
# onto a surface over a Julia array left the array blank, so every comparison before 2026-10-29 reported 0 pixels.
function pixels(p)
    s = Cairo.read_from_png(p)
    w, h = Int(s.width), Int(s.height)
    stride = ccall((:cairo_image_surface_get_stride, Cairo.libcairo), Int32, (Ptr{Nothing},), s.ptr)
    d = ccall((:cairo_image_surface_get_data, Cairo.libcairo), Ptr{UInt32}, (Ptr{Nothing},), s.ptr)
    return vec(copy(unsafe_wrap(Array, d, (Int(stride) ÷ 4, h))[1:w, :]))
end
a, b = pixels(ARGS[1]), pixels(ARGS[2])
d = count(a .!= b)
ch(x, k) = Int((UInt32(x) >> (8k)) & 0xff)
m = maximum((maximum(abs(ch(x, k) - ch(y, k)) for k in 0:3) for (x, y) in zip(a, b) if x != y); init = 0)
println("PNGDIFF pixels differing ", d, " of ", length(a), " (", round(100d / length(a); digits = 3), "%), largest channel difference ", m)
