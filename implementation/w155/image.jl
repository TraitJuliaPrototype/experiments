# W-155 (E-417 (c), E-419 (b)): TraitWorld's package image built afresh in this process' depot: its size
# (machine code and data) and build time. With JULIA_DEBUG_EXTERNAL_CIS=1 the image's writer prints what
# it keeps of other packages' code: by a backedge or a tag, by the G2 bit (compiler §9).
#     JULIA_DEBUG_EXTERNAL_CIS=1 julia --project=<library tree> image.jl
pkg = Base.identify_package("TraitWorld")
t = @elapsed (p = Base.compilecache(pkg))
ji, so = p
println("TraitWorld image | machine code ", so === nothing ? 0 : filesize(so), " bytes | data ", filesize(ji),
        " bytes | built in ", round(t; digits = 1), " s | julia ", Base.GIT_VERSION_INFO.commit_short)
