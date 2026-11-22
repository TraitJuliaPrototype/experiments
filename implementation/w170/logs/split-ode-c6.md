| part (ms) | ode-B | ode-A |
|---|---|---|
| wall, median (range) | **1577** (1558-1577), n=3 | **1573** (1561-1587), n=3 |
| Julia's start | 345 | 352 |
| load: the rest (finding files, reading) | 176 | 183 |
| compiling while inferring | 171 | 172 |
| code generation | 157 | 154 |
| load: the images' restore | 71 | 74 |
| load: the membership walk | 62 | 82 |
| inference | 67 | 59 |
| load: the edges' validation | 58 | 65 |
| garbage collection | 56 | 55 |
| load: methods' insertion and invalidation | 49 | 49 |
| load: the memberships' activation | 27 | 41 |
| load: the library's image hook: compiling | 50 | 17 |
| load: the library's image hook | 8 | 9 |
| lowering and parsing | 7 | 8 |
| the definition-time check: compiling | 11 |  |
| load: __init__ | 5 | 4 |
| the work itself | 3 | 5 |
| dispatch: lookup, the slow path | 4 | 2 |
| the definition-time check | 2 | 1 |
| the member check (the library's hook): compiling |  | 1 |
| the harness (set-up, `_` phases) | 215 | 217 |
| exit | 22 | 22 |
| profile samples (classed) | 1005 | 990 |
