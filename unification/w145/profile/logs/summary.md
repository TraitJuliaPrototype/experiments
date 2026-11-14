### table

`E-388 table 2026-11-14T17:44:29+01:00 load 0.26 0.71 0.97 | /p/projects/coen/julia-trait-bound/julia-unified/julia 86deee2f98* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 382 ms | image restore 141; image validation 133; loading, the rest 52; a method's activation 35 |
| read | 4 ms | code generation 3; compiling while inferring 1; the work itself 1 |
| summary | 3 ms | code generation 2; inference 1 |
| plot | 78 ms | the work itself 53; code generation 21 |
| edit of summarize, first | 2577 ms | definition-time check: compiling its own code 2123; definition-time check: inferring 451 |
| edit of summarize, second | 446 ms | definition-time check: inferring 445 |
| summary after the edit | 18 ms | code generation 15; inference 1; compiling while inferring 1 |

### ode

`E-388 ode 2026-11-14T17:44:56+01:00 load 0.54 0.74 0.97 | /p/projects/coen/julia-trait-bound/julia-unified/julia 86deee2f98* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 333 ms | image validation 102; image restore 100; loading, the rest 59; a method's activation 44; membership activation 18 |
| first solve (Lorenz, Tsit5) | 181 ms | code generation 104; inference 50; compiling while inferring 23 |
| first stiff solve (Robertson, Rodas5) | 139 ms | code generation 51; compiling while inferring 49; inference 36 |
| a new right-hand side (a closure) | 100 ms | code generation 52; inference 38; compiling while inferring 7 |
| the solves again | 3 ms | the work itself 2; lowering and parsing 1; method lookup 1 |

### forks

`E-388 forks 2026-11-14T17:35:43+01:00 load 0.57 0.66 1.07 | /p/projects/coen/julia-trait-bound/julia-unified/julia 86deee2f98* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 1017 ms | image validation 458; image restore 250; loading, the rest 102; a method's activation 77 |
| read | 35 ms | code generation 17; definition-time check: compiling its own code 8; the work itself 4 |
| show | 208 ms | code generation 169; inference 22; compiling while inferring 12 |
| describe | 796 ms | code generation 642; inference 115 |
| select and filter | 75 ms | code generation 61; inference 8 |
| sort | 82 ms | the work itself 40; collector 27; method lookup 16 |
| groupby and combine | 26 ms | code generation 22; the work itself 2 |
| a user's function by row | 121 ms | code generation 101; inference 9; compiling while inferring 6 |
| join | 78 ms | code generation 35; the work itself 21; method lookup 13; collector 7 |
| describe again | 3 ms | the work itself 3; method lookup 0 |

### upstream

`E-388 upstream 2026-11-14T17:36:06+01:00 load 0.79 0.70 1.08 | /p/projects/coen/julia-trait-bound/julia-unified/julia 86deee2f98* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 752 ms | image validation 395; image restore 193; loading, the rest 86; a method's activation 74 |
| read | 3070 ms | code generation 2063; inference 878 |
| show | 1443 ms | code generation 1010; inference 369 |
| describe | 1530 ms | code generation 766; inference 693 |
| select and filter | 230 ms | code generation 158; inference 58 |
| sort | 1551 ms | inference 911; code generation 563 |
| groupby and combine | 828 ms | code generation 540; inference 246 |
| a user's function by row | 335 ms | code generation 234; inference 75; compiling while inferring 22 |
| join | 1354 ms | code generation 900; inference 338; compiling while inferring 100 |
| describe again | 4 ms | the work itself 4 |

### upstream-vanilla

`E-388 upstream-vanilla 2026-11-14T17:37:14+01:00 load 0.97 0.78 1.08 | /p/projects/coen/julia-trait-bound/julia-vanilla/julia 45b6d15e34* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| load | 575 ms | image validation 268; image restore 156; loading, the rest 82; a method's activation 66 |
| read | 3333 ms | code generation 2667; inference 547 |
| show | 1267 ms | code generation 1024; inference 186 |
| describe | 1261 ms | code generation 782; inference 412 |
| select and filter | 210 ms | code generation 166; inference 30 |
| sort | 1329 ms | code generation 743; inference 516; compiling while inferring 66 |
| groupby and combine | 902 ms | code generation 698; inference 163 |
| a user's function by row | 303 ms | code generation 231; inference 46; compiling while inferring 21 |
| join | 1536 ms | code generation 1245; inference 184; compiling while inferring 92 |
| describe again | 4 ms | the work itself 4 |

### nd

`E-388 nd 2026-11-14T17:38:17+01:00 load 1.05 0.84 1.08 | /p/projects/coen/julia-trait-bound/julia-unified/julia 86deee2f98* TraitWorld 2072e75 TDE b730628 forks 439bae7 | one thread, product setting, strict mode off`

| Phase | Time | Where it goes (ms) |
|---|---|---|
| the whole workload (load, first pass, again, parameters, a changed model, a graph type) | 44033 ms | code generation 25407; inference 11493; compiling while inferring 2466 |

