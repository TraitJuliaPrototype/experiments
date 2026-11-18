### table-fix

`E-388 table 2026-11-14T19:07:41+01:00 load 0.76 1.71 2.63 | /p/projects/coen/julia-trait-bound/julia-unified/julia 21c9b33e39* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 385 ms | image restore 148; image validation 129; loading, the rest 53; a method's activation 34 |
| read | 4 ms | code generation 3; compiling while inferring 1; the work itself 1 |
| summary | 3 ms | code generation 2; inference 1 |
| plot | 84 ms | the work itself 57; code generation 23 |
| edit of summarize, first | 2514 ms | definition-time check: compiling its own code 2061; definition-time check: inferring 450 |
| edit of summarize, second | 455 ms | definition-time check: inferring 453 |
| summary after the edit | 17 ms | code generation 15; inference 1; compiling while inferring 1 |

### ode-fix

`E-388 ode 2026-11-14T19:08:13+01:00 load 0.78 1.63 2.57 | /p/projects/coen/julia-trait-bound/julia-unified/julia 21c9b33e39* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 328 ms | image validation 102; image restore 98; loading, the rest 58; a method's activation 43; membership activation 17 |
| first solve (Lorenz, Tsit5) | 171 ms | code generation 100; inference 44; compiling while inferring 23 |
| first stiff solve (Robertson, Rodas5) | 128 ms | code generation 50; compiling while inferring 44; inference 32 |
| a new right-hand side (a closure) | 93 ms | code generation 50; inference 32; compiling while inferring 7 |
| the solves again | 3 ms | method lookup 1; lowering and parsing 1; the work itself 1 |

### forks-fix

`E-388 forks 2026-11-14T19:08:22+01:00 load 0.81 1.61 2.55 | /p/projects/coen/julia-trait-bound/julia-unified/julia 21c9b33e39* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 1015 ms | image validation 449; image restore 259; loading, the rest 102; a method's activation 77 |
| read | 35 ms | code generation 18; definition-time check: compiling its own code 9; the work itself 3 |
| show | 207 ms | code generation 172; inference 18; compiling while inferring 13 |
| describe | 781 ms | code generation 652; inference 91 |
| select and filter | 75 ms | code generation 60; inference 5; compiling while inferring 5 |
| sort | 35 ms | the work itself 17; collector 11; method lookup 7 |
| groupby and combine | 26 ms | code generation 21; compiling while inferring 2; the work itself 1 |
| a user's function by row | 167 ms | code generation 141; compiling while inferring 9; inference 8 |
| join | 76 ms | code generation 35; the work itself 22; method lookup 10; collector 7 |
| describe again | 3 ms | the work itself 3 |

### upstream-fix

`E-388 upstream 2026-11-14T19:08:45+01:00 load 0.78 1.55 2.51 | /p/projects/coen/julia-trait-bound/julia-unified/julia 21c9b33e39* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 718 ms | image validation 313; loading, the rest 211; image restore 129; a method's activation 57 |
| read | 2951 ms | code generation 2057; inference 770 |
| show | 1371 ms | code generation 990; inference 319 |
| describe | 1486 ms | code generation 796; inference 615 |
| select and filter | 237 ms | code generation 169; inference 53 |
| sort | 1457 ms | inference 816; code generation 565 |
| groupby and combine | 805 ms | code generation 570; inference 189; compiling while inferring 45 |
| a user's function by row | 348 ms | code generation 241; inference 81; compiling while inferring 23 |
| join | 1258 ms | code generation 862; inference 280; compiling while inferring 99 |
| describe again | 4 ms | the work itself 4 |

