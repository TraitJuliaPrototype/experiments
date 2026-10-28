# Two PNGs compared pixel by pixel (Cairo): the share of pixels that differ and the largest channel difference.
#     julia --project=TraitMakie experiments/x3/tools/pngdiff.jl a.png b.png
using Cairo
function pixels(p)
    s = Cairo.read_from_png(p)
    buf = zeros(UInt32, Int(s.height), Int(s.width))      # a surface over a Julia array, the PNG painted onto it
    img = Cairo.CairoARGBSurface(buf)
    c = Cairo.CairoContext(img); Cairo.set_source_surface(c, s, 0, 0); Cairo.paint(c); Cairo.flush(img)
    return vec(copy(buf))
end
a, b = pixels(ARGS[1]), pixels(ARGS[2])
d = count(a .!= b)
ch(x, k) = Int((UInt32(x) >> (8k)) & 0xff)
m = maximum((maximum(abs(ch(x, k) - ch(y, k)) for k in 0:3) for (x, y) in zip(a, b) if x != y); init = 0)
println("PNGDIFF pixels differing ", d, " of ", length(a), " (", round(100d / length(a); digits = 3), "%), largest channel difference ", m)
