# E-361 control: a program whose only dependency is a JLL package with an `__init__`.
using Libiconv_jll
function (@main)(args::Vector{String})::Cint
    println(Core.stdout, "libiconv at ", basename(Libiconv_jll.libiconv_path))
    return 0
end
