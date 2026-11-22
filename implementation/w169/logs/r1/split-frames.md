| part (ms) | frames-up-V | frames-up-H | frames-facts-H | frames-forks-H |
|---|---|---|---|---|
| wall, median (range) | **16596** (16426-17280), n=3 | **16781** (16684-17324), n=3 | **10218** (9950-11072), n=3 | **10017** (9647-10035), n=3 |
| Julia's start | 189 | 363 | 356 | 354 |
| code generation | 7309 | 7217 | 2469 | 1716 |
| load: the rest (finding files, reading) | 2154 | 2130 | 2161 | 2148 |
| load: the edges' validation | 1366 | 1401 | 1307 | 1564 |
| load: the images' restore | 1280 | 1343 | 1329 | 1337 |
| inference | 1661 | 1534 | 366 | 393 |
| load: methods' insertion and invalidation | 866 | 892 | 887 | 894 |
| garbage collection | 731 | 871 | 522 | 645 |
| compiling while inferring | 366 | 364 | 135 | 92 |
| load: package callbacks | 127 | 131 | 173 | 180 |
| load: __init__ | 142 | 149 | 143 | 141 |
| load: the library's image hook |  |  |  | 74 |
| the work itself | 15 | 17 | 17 | 17 |
| load: __init__: compiling | 22 | 9 | 8 | 8 |
| load: the membership walk |  |  |  | 28 |
| dispatch: lookup, the slow path | 8 | 7 | 4 | 9 |
| load: the library's image hook: compiling |  |  |  | 25 |
| load: the memberships' activation |  |  |  | 21 |
| lowering and parsing | 1 | 2 | 2 | 2 |
| dispatch: the runtime's fast path | 1 |  |  | 1 |
| the member check (the library's hook): compiling |  | 1 |  |  |
| the harness (set-up, `_` phases) | 214 | 208 | 203 | 226 |
| exit | 144 | 142 | 137 | 141 |
| profile samples (classed) | 16242 | 16357 | 9260 | 9342 |

Phases, median of the unprofiled runs: ms (compiling, of it again; the collector) and the classes of 5 % or more:

- **frames-up-V**
  - load: 1068.8 ms (compiling 0.0, again 0.0; gc 42.3, 48 MB) | load: the rest (finding files, reading) 459; load: the edges' validation 273; load: the images' restore 222; load: methods' insertion and invalidation 68
  - first work: 4416.1 ms (compiling 4408.3, again 996.0; gc 181.0, 341 MB) | code generation 3450; inference 618
  - again: 1.7 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | garbage collection 1; dispatch: lookup, the slow path 0; the work itself 0
  - nine loads: 5161.1 ms (compiling 29.0, again 0.0; gc 218.8, 225 MB) | load: the rest (finding files, reading) 1695; load: the edges' validation 1093; load: the images' restore 1058; load: methods' insertion and invalidation 799
  - after the loads: 5399.6 ms (compiling 5394.9, again 5394.9; gc 322.7, 443 MB) | code generation 3852; inference 1043; garbage collection 303
  - again after: 1.9 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | the work itself 2
- **frames-up-H**
  - load: 1200.8 ms (compiling 0.0, again 0.0; gc 45.7, 49 MB) | load: the rest (finding files, reading) 521; load: the edges' validation 298; load: the images' restore 254; load: methods' insertion and invalidation 74
  - first work: 4470.9 ms (compiling 4462.7, again 994.5; gc 178.3, 352 MB) | code generation 3444; inference 657
  - again: 1.8 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | the work itself 2
  - nine loads: 5151.8 ms (compiling 15.9, again 0.0; gc 241.8, 224 MB) | load: the rest (finding files, reading) 1609; load: the edges' validation 1103; load: the images' restore 1089; load: methods' insertion and invalidation 818
  - after the loads: 5240.0 ms (compiling 5235.5, again 5235.5; gc 343.2, 453 MB) | code generation 3765; inference 876; garbage collection 393
  - again after: 1.8 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | the work itself 2
- **frames-facts-H**
  - load: 1058.3 ms (compiling 0.0, again 0.0; gc 45.3, 43 MB) | load: the rest (finding files, reading) 542; load: the images' restore 201; load: the edges' validation 183; load: methods' insertion and invalidation 74
  - first work: 1768.7 ms (compiling 1758.1, again 8.9; gc 73.2, 105 MB) | code generation 1377; inference 206; compiling while inferring 90
  - again: 2.0 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | the work itself 2
  - nine loads: 5232.5 ms (compiling 16.4, again 0.0; gc 257.9, 222 MB) | load: the rest (finding files, reading) 1618; load: the images' restore 1129; load: the edges' validation 1124; load: methods' insertion and invalidation 813
  - after the loads: 1459.0 ms (compiling 1454.0, again 1454.0; gc 170.7, 91 MB) | code generation 1085; garbage collection 167; inference 158
  - again after: 2.0 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | the work itself 2
- **frames-forks-H**
  - load: 1278.0 ms (compiling 25.8, again 0.0; gc 37.7, 65 MB) | load: the rest (finding files, reading) 502; load: the edges' validation 253; load: the images' restore 229; load: methods' insertion and invalidation 74; garbage collection 65
  - first work: 196.7 ms (compiling 186.1, again 0.0; gc 41.5, 8 MB) | code generation 158; inference 23
  - again: 2.2 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | dispatch: lookup, the slow path 1; the work itself 1
  - nine loads: 5546.4 ms (compiling 16.4, again 0.0; gc 342.3, 247 MB) | load: the rest (finding files, reading) 1646; load: the edges' validation 1312; load: the images' restore 1109; load: methods' insertion and invalidation 820; garbage collection 325
  - after the loads: 2269.9 ms (compiling 2264.4, again 2264.4; gc 176.3, 210 MB) | code generation 1550; inference 370; garbage collection 256
  - again after: 2.4 ms (compiling 0.0, again 0.0; gc 0.0, 1 MB) | the work itself 2

