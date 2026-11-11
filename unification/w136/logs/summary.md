| Case | Form | Last phase reached | Exception | Message lines | Message bytes | Frames | First frame; first frame outside Julia and the library's runtime | Warnings | Signatures as tuple types | Library frames above the user's |
|---|---|---|---|---|---|---|---|---|---|---|
| 01_missing_operation | plain-unified | call | MethodError | 2 | 167 | 6 | Main.Geometry lib_plain.jl:14 ; Main.Geometry lib_plain.jl:14 | 0 | 0 | 0 |
| 01_missing_operation | plain | call | MethodError | 2 | 167 | 6 | Main.Geometry lib_plain.jl:14 ; Main.Geometry lib_plain.jl:14 | 0 | 0 | 0 |
| 01_missing_operation | trait | definition | ImplementError | 2 | 128 | 7 | TraitWorld TraitWorld-unified/src/implement.jl:122 ; cases/01_missing_operation.trait.jl:7 | 0 | 0 | 3 |
| 02a_result_int | plain-unified | end | none |  |  |  |  | 0 | 0 |  |
| 02a_result_int | plain | end | none |  |  |  |  | 0 | 0 |  |
| 02a_result_int | trait | definition | ImplementError | 2 | 153 | 7 | TraitWorld TraitWorld-unified/src/implement.jl:122 ; cases/02a_result_int.trait.jl:8 | 0 | 0 | 3 |
| 02b_result_symbol | plain-unified | call | MethodError | 10 | 455 | 6 | Main.Geometry lib_plain.jl:15 ; Main.Geometry lib_plain.jl:15 | 0 | 0 | 0 |
| 02b_result_symbol | plain | call | MethodError | 10 | 455 | 6 | Main.Geometry lib_plain.jl:15 ; Main.Geometry lib_plain.jl:15 | 0 | 0 | 0 |
| 02b_result_symbol | trait | definition | ImplementError | 2 | 154 | 7 | TraitWorld TraitWorld-unified/src/implement.jl:122 ; cases/02b_result_symbol.trait.jl:6 | 0 | 0 | 3 |
| 03a_wrong_argument | plain-unified | call | MethodError | 6 | 312 | 4 | cases/03a_wrong_argument.plain.jl:9 ; cases/03a_wrong_argument.plain.jl:9 | 0 | 0 | 0 |
| 03a_wrong_argument | plain | call | MethodError | 6 | 312 | 4 | cases/03a_wrong_argument.plain.jl:9 ; cases/03a_wrong_argument.plain.jl:9 | 0 | 0 | 0 |
| 03a_wrong_argument | trait | call | MethodError | 7 | 426 | 4 | cases/03a_wrong_argument.trait.jl:11 ; cases/03a_wrong_argument.trait.jl:11 | 0 | 0 | 0 |
| 03b_wrong_operation_argument | plain-unified | call | MethodError | 6 | 350 | 4 | cases/03b_wrong_operation_argument.plain.jl:10 ; cases/03b_wrong_operation_argument.plain.jl:10 | 0 | 0 | 0 |
| 03b_wrong_operation_argument | plain | call | MethodError | 6 | 350 | 4 | cases/03b_wrong_operation_argument.plain.jl:10 ; cases/03b_wrong_operation_argument.plain.jl:10 | 0 | 0 | 0 |
| 03b_wrong_operation_argument | trait | call | MethodError | 9 | 579 | 5 | Main.Geometry lib_trait.jl:22 ; Main.Geometry lib_trait.jl:22 | 0 | 0 | 0 |
| 04a_ambiguity_two_traits | plain-unified | end | none |  |  |  |  | 0 | 0 |  |
| 04a_ambiguity_two_traits | plain | end | none |  |  |  |  | 0 | 0 |  |
| 04a_ambiguity_two_traits | trait-strict | second membership | ImplementError | 3 | 330 | 7 | TraitWorld TraitWorld-unified/src/implement.jl:141 ; cases/04a_ambiguity_two_traits.trait.jl:12 | 0 | 0 | 3 |
| 04a_ambiguity_two_traits | trait | call | MethodError | 10 | 352 | 4 | cases/04a_ambiguity_two_traits.trait.jl:14 ; cases/04a_ambiguity_two_traits.trait.jl:14 | 1 | 0 | 0 |
| 04b_ambiguity_two_arguments | plain-unified | call | MethodError | 10 | 435 | 4 | cases/04b_ambiguity_two_arguments.plain.jl:16 ; cases/04b_ambiguity_two_arguments.plain.jl:16 | 0 | 0 | 0 |
| 04b_ambiguity_two_arguments | plain | call | MethodError | 10 | 435 | 4 | cases/04b_ambiguity_two_arguments.plain.jl:16 ; cases/04b_ambiguity_two_arguments.plain.jl:16 | 0 | 0 | 0 |
| 04b_ambiguity_two_arguments | trait | call | MethodError | 10 | 435 | 4 | cases/04b_ambiguity_two_arguments.trait.jl:19 ; cases/04b_ambiguity_two_arguments.trait.jl:19 | 1 | 0 | 0 |
| 05_pirate | plain-unified | end | none |  |  |  |  | 0 | 0 |  |
| 05_pirate | plain | end | none |  |  |  |  | 0 | 0 |  |
| 05_pirate | trait-strict | pirate | PirateError | 3 | 484 | 6 | TraitWorld TraitWorld-unified/src/strict.jl:215 ; cases/05_pirate.trait.jl:13 | 0 | 0 | 2 |
| 05_pirate | trait | end | none |  |  |  |  | 0 | 0 |  |
| 06_break_after | plain-unified | call | MethodError | 11 | 585 | 7 | Base ./rounding.jl:481 ; Main.Geometry lib_plain.jl:15 | 0 | 0 | 0 |
| 06_break_after | plain | call | MethodError | 11 | 585 | 7 | Base ./rounding.jl:481 ; Main.Geometry lib_plain.jl:15 | 0 | 0 | 0 |
| 06_break_after | trait-strict | later method | ImplementError | 5 | 488 | 6 | TraitWorld TraitWorld-unified/src/implement.jl:350 ; cases/06_break_after.trait.jl:11 | 0 | 0 | 2 |
| 06_break_after | trait | later method | ImplementError | 5 | 488 | 6 | TraitWorld TraitWorld-unified/src/implement.jl:350 ; cases/06_break_after.trait.jl:11 | 0 | 0 | 2 |
| 07a_never_joined | plain-unified | call | MethodError | 6 | 311 | 4 | cases/07a_never_joined.plain.jl:9 ; cases/07a_never_joined.plain.jl:9 | 0 | 0 | 0 |
| 07a_never_joined | plain | call | MethodError | 6 | 311 | 4 | cases/07a_never_joined.plain.jl:9 ; cases/07a_never_joined.plain.jl:9 | 0 | 0 | 0 |
| 07a_never_joined | trait | call | MethodError | 7 | 392 | 4 | cases/07a_never_joined.trait.jl:9 ; cases/07a_never_joined.trait.jl:9 | 0 | 0 | 0 |
| 07b_use_before_implement | trait | call | ImplementError | 2 | 140 | 6 | TraitWorld TraitWorld-unified/src/implement.jl:668 ; cases/07b_use_before_implement.trait.jl:9 | 0 | 0 | 2 |
| 08_member_in_running_loop | plain-unified | end | none |  |  |  |  | 1 | 0 |  |
| 08_member_in_running_loop | plain | end | none |  |  |  |  | 1 | 0 |  |
| 08_member_in_running_loop | trait | call | MethodError | 6 | 285 | 6 | ./array.jl:1344 [inlined] ; Main cases/08_member_in_running_loop.trait.jl:16 | 1 | 0 | 0 |
| 09_library_outside_contract | plain-unified | call | FieldError | 1 | 84 | 6 | ./Base_compiler.jl:57 [inlined] ; Main.Geometry cases/09_library_outside_contract.plain.jl:8 | 0 | 0 | 0 |
| 09_library_outside_contract | plain | call | FieldError | 1 | 84 | 6 | ./Base_compiler.jl:57 [inlined] ; Main.Geometry cases/09_library_outside_contract.plain.jl:8 | 0 | 0 | 0 |
| 09_library_outside_contract | trait | library | TraitUseError | 2 | 175 | 8 | TraitWorld TraitWorld-unified/src/classify.jl:440 ; cases/09_library_outside_contract.trait.jl:10 | 0 | 0 | 4 |
