# FactsCompiler: the facts policy as a mode of Julia's compiler (stage 1)

Plan: `../../writeup/plans/2026-10-17-policy-in-compiler-plan.md`, part (A), stage 1.

`Compiler/` is a copy of `julia-1.13/Compiler` (the patched 1.13.2 tree) with the facts rules in
`src/facts.jl`, hooked into `find_method_matches`, `concrete_eval_eligible` and `return_type_tfunc`.
`env/` develops it under Compiler's own name and uuid.

    JULIA_FACTS_COMPILER=1 julia --project=env -e 'using Compiler; Compiler.activate!(; reflection = true, codegen = true); …'

`activate!` bootstraps the copy (about 23 s per session), then sets the mode from
`JULIA_FACTS_COMPILER`, so the compiler's own code stays compiled plainly. Code in the system image
and in package images was compiled plainly and is used as it is: measure with `--pkgimages=no`.

Checks so far: a single-method call at `Any` (`one_method(v[1])`, `v::Vector{Any}`) is typed
`Float64` with the mode off and `Any` with it on; a loop over 10⁶ such calls takes 0.99 ms off,
26 ms on (lesson 1.5 at its worst).
