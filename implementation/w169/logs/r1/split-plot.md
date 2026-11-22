| part (ms) | plot-H | plot-plain-H | report-H | report-plain-H |
|---|---|---|---|---|
| wall, median (range) | **1268** (1264-1450), n=3 | **1108** (1088-1257), n=3 | **1418** (1296-1448), n=3 | **1258** (1238-1309), n=3 |
| Julia's start | 324 | 232 | 344 | 325 |
| load: the rest (finding files, reading) | 237 | 230 | 254 | 259 |
| code generation | 78 | 74 | 92 | 82 |
| the work itself | 58 | 49 | 97 | 85 |
| load: the images' restore | 69 | 57 | 96 | 55 |
| load: the edges' validation | 52 | 42 | 84 | 46 |
| load: __init__ | 45 | 52 | 47 | 59 |
| load: methods' insertion and invalidation | 31 | 28 | 35 | 31 |
| compiling while inferring | 49 | 41 | 11 | 11 |
| garbage collection | 21 | 21 | 17 | 21 |
| inference | 14 | 17 | 9 | 8 |
| load: the library's image hook: compiling | 11 |  | 14 |  |
| the definition-time check: compiling | 13 |  | 11 |  |
| lowering and parsing | 2 | 3 | 4 | 4 |
| load: the library's image hook | 4 |  | 7 |  |
| load: the memberships' activation | 3 |  | 3 |  |
| load: the membership walk | 2 |  | 3 |  |
| the definition-time check | 1 |  | 3 |  |
| the member check (the library's hook) |  |  | 2 |  |
| dispatch: lookup, the slow path |  | 1 |  |  |
| load: package callbacks | 1 |  |  |  |
| the harness (set-up, `_` phases) | 199 | 205 | 220 | 212 |
| exit | 58 | 59 | 62 | 60 |
| profile samples (classed) | 702 | 605 | 770 | 644 |

Phases, median of the unprofiled runs: ms (compiling, of it again; the collector) and the classes of 5 % or more:

- **plot-H**
  - load: 509.5 ms (compiling 35.6, again 0.0; gc 0.0, 20 MB) | load: the rest (finding files, reading) 237; load: the images' restore 69; load: the edges' validation 52; load: __init__ 45; load: methods' insertion and invalidation 31
  - first run: 171.6 ms (compiling 119.4, again 0.0; gc 0.0, 5 MB) | code generation 65; compiling while inferring 49; the work itself 43; inference 14
  - second run: 9.6 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | the work itself 10
- **plot-plain-H**
  - load: 431.5 ms (compiling 14.1, again 0.0; gc 0.0, 15 MB) | load: the rest (finding files, reading) 230; load: the images' restore 57; load: __init__ 52; load: the edges' validation 42; load: methods' insertion and invalidation 28
  - first run: 173.8 ms (compiling 125.2, again 0.0; gc 0.0, 7 MB) | code generation 59; compiling while inferring 41; the work itself 37; garbage collection 21; inference 17
  - second run: 10.5 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | the work itself 10
- **report-H**
  - load: 624.6 ms (compiling 66.6, again 0.0; gc 0.0, 26 MB) | load: the rest (finding files, reading) 254; load: the images' restore 96; load: the edges' validation 84; load: __init__ 47; code generation 43; load: methods' insertion and invalidation 35
  - first run: 135.2 ms (compiling 61.4, again 0.0; gc 0.0, 4 MB) | the work itself 64; code generation 49; compiling while inferring 11; inference 9
  - second run: 29.8 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | the work itself 30
- **report-plain-H**
  - load: 503.9 ms (compiling 41.9, again 0.0; gc 0.0, 16 MB) | load: the rest (finding files, reading) 259; load: __init__ 59; load: the images' restore 55; code generation 47; load: the edges' validation 46; load: methods' insertion and invalidation 31
  - first run: 127.0 ms (compiling 58.0, again 0.0; gc 0.0, 4 MB) | the work itself 52; code generation 35; garbage collection 21; compiling while inferring 11; inference 8
  - second run: 29.6 ms (compiling 0.0, again 0.0; gc 0.0, 0 MB) | the work itself 30

