| Case | Form | Last phase reached | Exception | Message lines | Message bytes | Frames | First frame; first frame outside Julia and the library's runtime | Warnings | Signatures as tuple types | Library frames above the user's |
|---|---|---|---|---|---|---|---|---|---|---|
| 01_missing_operation | plain | call | MethodError | 2 | 167 | 6 | Main.Geometry lib_plain.jl:14 ; Main.Geometry lib_plain.jl:14 | 0 | 0 | 0 |
| 02a_result_int | plain | end | none |  |  |  |  | 0 | 0 |  |
| 02b_result_symbol | plain | call | MethodError | 10 | 455 | 6 | Main.Geometry lib_plain.jl:15 ; Main.Geometry lib_plain.jl:15 | 0 | 0 | 0 |
| 03a_wrong_argument | plain | call | MethodError | 6 | 315 | 4 | cases/03a_wrong_argument.plain.jl:9 ; cases/03a_wrong_argument.plain.jl:9 | 0 | 0 | 0 |
| 03b_wrong_operation_argument | plain | call | MethodError | 6 | 353 | 4 | cases/03b_wrong_operation_argument.plain.jl:10 ; cases/03b_wrong_operation_argument.plain.jl:10 | 0 | 0 | 0 |
| 04a_ambiguity_two_traits | plain | end | none |  |  |  |  | 0 | 0 |  |
| 04b_ambiguity_two_arguments | plain | call | MethodError | 10 | 441 | 4 | cases/04b_ambiguity_two_arguments.plain.jl:16 ; cases/04b_ambiguity_two_arguments.plain.jl:16 | 0 | 0 | 0 |
| 05_pirate | plain | end | none |  |  |  |  | 0 | 0 |  |
| 06_break_after | plain | call | MethodError | 11 | 585 | 7 | Base ./rounding.jl:481 ; Main.Geometry lib_plain.jl:15 | 0 | 0 | 0 |
| 07a_never_joined | plain | call | MethodError | 6 | 314 | 4 | cases/07a_never_joined.plain.jl:9 ; cases/07a_never_joined.plain.jl:9 | 0 | 0 | 0 |
| 08_member_in_running_loop | plain | end | none |  |  |  |  | 1 | 0 |  |
| 09_library_outside_contract | plain | call | FieldError | 1 | 84 | 6 | ./Base_compiler.jl:57 [inlined] ; Main.Geometry cases/09_library_outside_contract.plain.jl:8 | 0 | 0 | 0 |
