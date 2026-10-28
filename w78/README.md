# W-78: a bounded function defined again after its trait module is complete

Traits reference §2 (open issue 79, option (b), the user 2026-10-28): such a definition goes through the module's
end for that function. Built in TraitWorld (`_tw_lower`, `_eval_stmt`, `_finish_function` in `src/trait_module.jl`):
Julia's lowering hands each statement evaluated into a complete trait module to `@stmt`, then the module's end runs
for the function it defines. The test is `TraitWorld/test/redefine.jl`.

How to run (from this directory, the patched Julia):

    julia --project=../../TraitWorld edit_cases.jl                 # by `Core.eval`
    cd revise && julia --project=. revise_case.jl                  # Revise, `@trait_module module … end` in a file
    cd revise && julia --project=. revise_block.jl                 # Revise, a plain module holding `@trait_module begin … end`

## Results (2026-10-28, julia-1.13 1c2e98b58e, TraitWorld with W-78)

| Case | Result | Log |
|---|---|---|
| an edit of the body by `Core.eval` | the worker replaced (2 methods before and after), its plain caller compiled again (6.0, 7.0) | `logs/edit_cases.log` |
| an edit that breaks a rule | a warning at the definition, `TraitUseError` at the call | same |
| a new bounded function after the end, then a shape with a second bound | 3, then 6 | same |
| an ordinary definition evaluated into the module | stays ordinary | same |
| Revise, `includet` of a file whose top level is `@trait_module module … end` | `syntax: "module" expression not at top level`, also with TraitWorld's hooks off: Revise cannot load the file | `logs/revise_module.log` |
| Revise, a plain module holding `@trait_module begin … end`, the bounded function's body edited | the block is one statement for Revise: the edit does not take effect (3.0 after the edit); with the hooks off its re-evaluation is refused at the `@implement` (a redeclaration) | `logs/revise_block.log`, `logs/revise_block_nohooks.log` |

Revise's case is traits T-81 and open issue 81.
