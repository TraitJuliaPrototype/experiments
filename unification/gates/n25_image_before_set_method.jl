# Gate (W-140; compiler §5.5): code in a package image, compiled where its callee had no method at a
# trait, is reached by a later membership: the membership replays the trait's method at the member and
# invalidates the caller, as a method's insertion does. Two orders, each in its own process: the method
# at the trait defined before the image loads, and after.
script = joinpath(@__DIR__, "..", "w140", "image_then_method.jl")
for order in ("method-first", "image-first")
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) $script $order`
    @assert success(pipeline(cmd; stdout = stdout, stderr = stderr)) "the image's code is stale after the membership ($order)"
end
println("n25_image_before_set_method: OK")
