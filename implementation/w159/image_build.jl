# W-159 (G-4, an image's size and build time): writes each package's image anew into the first depot (a scratch
# depot of the driver) and reports its time and its files' sizes. The packages' dependencies must have valid images
# (the driver's preflight). One line per package: IMAGE <pkg> <seconds> s | ji <bytes> | so <bytes>
#     julia --project=<env> image_build.jl <package>...
for p in ARGS
    id = Base.identify_package(p)
    id === nothing && (println("IMAGE ", p, " not in the environment"); continue)
    t = @elapsed (r = Base.compilecache(id, devnull, devnull))
    ji, so = r isa Tuple ? r : (r, nothing)
    println("IMAGE ", p, " ", round(t; digits = 2), " s | ji ", filesize(ji), " | so ", so === nothing ? 0 : filesize(so))
end
