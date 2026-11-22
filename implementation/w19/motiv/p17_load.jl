# W-19, P17: julia --project=<env with W19Docs> p17_load.jl -- the load time of W19Docs's image (precompiled first),
# and the number of external instances whose signature type has no hash the image brings.
t = @elapsed using W19Docs
println("using W19Docs: ", round(1e3t; digits = 1), " ms")
