# C-74's reproducer

`C74Probe`, a module compiled by facts (`@trait_module`), runs three closures in its workload: one in a task (`intask`), one directly (`direct`), and one in a task whose callee gains a more specific method after the workload (`intask_later`, `kernel(::Int)` defined last). It prints its closures' CodeInstances while its image is built (`build:`) and after its load (`load:`).

    bash run.sh        # the unified build; C74_JULIA=<julia> for another

On `unified` 24c8d4db60 (2026-11-08): `intask_later`'s task closure is kept in the image as two plain CodeInstances (`facts=false image=true`), its method's policy facts: the image's native compile inferred it again with its plain interpreter, after the later method invalidated the workload's facts code. The other closures are facts. Gate `../gates/n15_image_policy.jl` holds the case (a direct call's code is kept plain the same way). Fixed on `unified` 917e767d73 (E-311).
