# Precompile time and image sizes of the trait-world packages (TDE row 13, TraitMakie row 10):
# each package compiled again in its own process (its dependencies already compiled), then the
# sizes of its image (.ji) and native library (.so), and `using` in a fresh process.
#
#     JULIA_LOAD_PATH="<env with the packages>:@stdlib" julia --startup-file=no images.jl Pkg1 Pkg2 …
for name in ARGS
    id = Base.identify_package(name)
    t = @elapsed (paths = Base.compilecache(id))
    ji, so = paths isa Tuple ? paths : (paths, nothing)
    jl = joinpath(Sys.BINDIR, Base.julia_exename())
    tl = parse(Float64, readchomp(`$jl --startup-file=no $(Base.julia_cmd().exec[2:end]) -e "t = @elapsed using $name; print(t)"`))
    println(rpad(name, 28), "precompile ", round(t; digits = 1), " s; .ji ", round(filesize(ji) / 2^20; digits = 2), " MB, .so ",
            so === nothing ? "-" : string(round(filesize(so) / 2^20; digits = 2), " MB"), "; using ", round(tl; digits = 2), " s")
end
