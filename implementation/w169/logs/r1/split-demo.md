| part (ms) | table-H | table-plain-H | ode-H | ode-plain-H | odecb-H | odecb-plain-H |
|---|---|---|---|---|---|---|
| wall, median (range) | **696** (680-839), n=3 | **587** (585-717), n=3 | **1369** (1318-1489), n=3 | **1235** (1087-1236), n=3 | **1298** (1287-1373), n=3 | **930** (841-968), n=3 |
| Julia's start | 197 | 195 | 224 | 346 | 230 | 327 |
| code generation | 91 | 91 | 152 | 140 | 264 | 75 |
| load: the rest (finding files, reading) | 38 | 36 | 155 | 101 | 128 | 105 |
| compiling while inferring | 5 | 4 | 172 | 148 | 19 | 31 |
| load: the images' restore | 49 | 11 | 61 | 45 | 65 | 47 |
| inference | 10 | 11 | 66 | 94 | 38 | 17 |
| load: the edges' validation | 42 | 8 | 52 | 28 | 59 | 37 |
| load: methods' insertion and invalidation | 14 | 11 | 43 | 41 | 42 | 36 |
| garbage collection |  |  | 48 | 38 | 33 | 18 |
| load: the membership walk | 1 |  | 57 |  | 62 |  |
| load: the library's image hook: compiling | 14 |  | 45 |  | 47 |  |
| load: the memberships' activation |  |  | 25 |  | 28 |  |
| lowering and parsing | 3 | 3 | 7 | 5 | 7 | 5 |
| the definition-time check: compiling | 9 |  | 9 |  | 10 |  |
| load: the library's image hook | 3 |  | 7 |  | 13 |  |
| the work itself | 1 | 1 | 5 | 2 | 4 | 2 |
| load: __init__ |  |  | 3 | 3 | 3 | 2 |
| dispatch: lookup, the slow path |  |  | 3 |  | 8 |  |
| the definition-time check | 1 |  | 1 |  | 1 |  |
| the member check (the library's hook): compiling |  |  |  | 1 |  |  |
| the member check (the library's hook) | 1 |  |  |  |  |  |
| the harness (set-up, `_` phases) | 197 | 198 | 212 | 216 | 210 | 207 |
| exit | 20 | 19 | 22 | 21 | 24 | 23 |
| profile samples (classed) | 293 | 176 | 990 | 663 | 826 | 378 |

Phases, median of the unprofiled runs: ms (compiling, of it again; the collector) and the classes of 5 % or more:

- **table-H**
  - load: 215.4 ms (compiling 63.2, again 0.0; gc 0.0, 11 MB) | load: the images' restore 49; code generation 42; load: the edges' validation 42; load: the rest (finding files, reading) 38; load: the library's image hook: compiling 14; load: methods' insertion and invalidation 14
  - first run: 65.5 ms (compiling 63.5, again 0.0; gc 0.0, 5 MB) | code generation 50; inference 10; compiling while inferring 5
  - second run: 0.5 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | 
- **table-plain-H**
  - load: 111.1 ms (compiling 41.0, again 0.0; gc 0.0, 3 MB) | code generation 41; load: the rest (finding files, reading) 36; load: methods' insertion and invalidation 11; load: the images' restore 11; load: the edges' validation 8
  - first run: 65.2 ms (compiling 63.5, again 0.0; gc 0.0, 5 MB) | code generation 49; inference 11; compiling while inferring 4
  - second run: 0.5 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | 
- **ode-H**
  - load: 534.1 ms (compiling 96.3, again 12.6; gc 19.8, 59 MB) | load: the rest (finding files, reading) 155; load: the images' restore 61; load: the membership walk 57; load: the edges' validation 52; load: the library's image hook: compiling 45; load: methods' insertion and invalidation 43; code generation 36; garbage collection 31
  - first run: 374.8 ms (compiling 371.6, again 0.0; gc 16.4, 34 MB) | compiling while inferring 172; code generation 116; inference 66
  - second run: 2.0 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | the work itself 2
- **ode-plain-H**
  - load: 268.4 ms (compiling 41.8, again 0.0; gc 0.0, 12 MB) | load: the rest (finding files, reading) 101; code generation 45; load: the images' restore 45; load: methods' insertion and invalidation 41; load: the edges' validation 28
  - first run: 378.1 ms (compiling 374.4, again 0.0; gc 22.0, 48 MB) | compiling while inferring 148; code generation 95; inference 94; garbage collection 38
  - second run: 0.7 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | 
- **odecb-H**
  - load: 522.1 ms (compiling 79.2, again 12.8; gc 19.8, 60 MB) | load: the rest (finding files, reading) 128; load: the images' restore 65; load: the membership walk 62; load: the edges' validation 59; load: the library's image hook: compiling 47; load: methods' insertion and invalidation 42; garbage collection 33; load: the memberships' activation 28
  - first run: 305.5 ms (compiling 281.9, again 0.0; gc 16.8, 16 MB) | code generation 245; inference 37; compiling while inferring 18
  - second run: 2.7 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | dispatch: lookup, the slow path 3
- **odecb-plain-H**
  - load: 250.3 ms (compiling 14.2, again 0.0; gc 0.0, 12 MB) | load: the rest (finding files, reading) 105; load: the images' restore 47; load: the edges' validation 37; load: methods' insertion and invalidation 36; code generation 15
  - first run: 124.8 ms (compiling 123.3, again 0.0; gc 0.0, 8 MB) | code generation 59; compiling while inferring 31; garbage collection 18; inference 17
  - second run: 0.5 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | 

