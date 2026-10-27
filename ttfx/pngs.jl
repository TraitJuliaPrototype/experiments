# Each PNG's size, for the workloads' trailers.
"Each PNG's size in pixels (from its header) and bytes."
function pngs(dir, prefix)
    for f in sort(filter(n -> startswith(n, prefix) && endswith(n, ".png"), readdir(dir)))
        b = read(joinpath(dir, f)); w = ntoh(reinterpret(UInt32, b[17:20])[1]); h = ntoh(reinterpret(UInt32, b[21:24])[1])
        println("P ", f, " ", w, "x", h, " ", length(b), " bytes")
    end
end
