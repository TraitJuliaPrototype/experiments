| Case | Form | Last phase reached | Exception | Message lines | Message bytes | Frames | First frame; first frame outside Julia and the library's runtime | Warnings | Signatures as tuple types | Library frames above the user's |
|---|---|---|---|---|---|---|---|---|---|---|
| 01_missing_operation | trait | definition | ImplementError | 2 | 128 | 4 | cases/01_missing_operation.trait.jl:7 ; cases/01_missing_operation.trait.jl:7 | 0 | 0 | 0 |
| 02a_result_int | trait | definition | ImplementError | 2 | 153 | 4 | cases/02a_result_int.trait.jl:8 ; cases/02a_result_int.trait.jl:8 | 0 | 0 | 0 |
| 02b_result_symbol | trait | definition | ImplementError | 2 | 154 | 4 | cases/02b_result_symbol.trait.jl:6 ; cases/02b_result_symbol.trait.jl:6 | 0 | 0 | 0 |
| 03a_wrong_argument | trait | call | MethodError | 7 | 429 | 4 | cases/03a_wrong_argument.trait.jl:11 ; cases/03a_wrong_argument.trait.jl:11 | 0 | 0 | 0 |
| 03b_wrong_operation_argument | trait | call | OperationError | 3 | 211 | 5 | Main.Geometry lib_trait.jl:22 ; Main.Geometry lib_trait.jl:22 | 0 | 0 | 0 |
| 04a_ambiguity_two_traits | trait-strict | second membership | ImplementError | 3 | 330 | 4 | cases/04a_ambiguity_two_traits.trait.jl:12 ; cases/04a_ambiguity_two_traits.trait.jl:12 | 0 | 0 | 0 |
| 04a_ambiguity_two_traits | trait | call | MethodError | 10 | 358 | 4 | cases/04a_ambiguity_two_traits.trait.jl:14 ; cases/04a_ambiguity_two_traits.trait.jl:14 | 1 | 0 | 0 |
| 04b_ambiguity_two_arguments | trait | call | MethodError | 10 | 441 | 4 | cases/04b_ambiguity_two_arguments.trait.jl:19 ; cases/04b_ambiguity_two_arguments.trait.jl:19 | 1 | 0 | 0 |
| 05_pirate | trait-strict | pirate | PirateError | 3 | 484 | 4 | cases/05_pirate.trait.jl:13 ; cases/05_pirate.trait.jl:13 | 0 | 0 | 0 |
| 05_pirate | trait | end | none |  |  |  |  | 0 | 0 |  |
| 06_break_after | trait-strict | later method | ImplementError | 5 | 491 | 4 | cases/06_break_after.trait.jl:11 ; cases/06_break_after.trait.jl:11 | 0 | 0 | 0 |
| 06_break_after | trait | later method | ImplementError | 5 | 491 | 4 | cases/06_break_after.trait.jl:11 ; cases/06_break_after.trait.jl:11 | 0 | 0 | 0 |
| 07a_never_joined | trait | call | MethodError | 7 | 395 | 4 | cases/07a_never_joined.trait.jl:9 ; cases/07a_never_joined.trait.jl:9 | 0 | 0 | 0 |
| 07b_use_before_implement | trait | call | ImplementError | 2 | 140 | 6 | TraitWorld /p/projects/coen/julia-trait-bound/TraitWorld-base/src/implement.jl:721 ; TraitWorld /p/projects/coen/julia-trait-bound/TraitWorld-base/src/implement.jl:721 | 0 | 0 | 0 |
| 08_member_in_running_loop | trait | call | MethodError | 6 | 285 | 6 | ./array.jl:1344 [inlined] ; Main cases/08_member_in_running_loop.trait.jl:16 | 1 | 0 | 0 |
| 09_library_outside_contract | trait | library | TraitUseError | 2 | 180 | 4 | cases/09_library_outside_contract.trait.jl:10 ; cases/09_library_outside_contract.trait.jl:10 | 0 | 0 | 0 |
