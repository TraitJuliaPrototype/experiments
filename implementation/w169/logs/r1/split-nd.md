| part (ms) | nd-H |
|---|---|
| wall, median (range) | **42395** (42318-42472), n=2 |
| Julia's start | 343 |
| code generation | 27030 |
| inference | 6612 |
| compiling while inferring | 2335 |
| load: the rest (finding files, reading) | 1130 |
| garbage collection | 966 |
| the work itself | 870 |
| load: methods' insertion and invalidation | 672 |
| load: the images' restore | 450 |
| load: the edges' validation | 391 |
| dispatch: the box's checks | 379 |
| the member check (the library's hook): compiling | 231 |
| dispatch: lookup, the slow path | 223 |
| load: __init__: compiling | 81 |
| load: __init__ | 77 |
| load: the membership walk | 73 |
| lowering and parsing | 68 |
| load: the library's image hook: compiling | 51 |
| load: the memberships' activation | 35 |
| load: the library's image hook | 33 |
| dispatch: the runtime's fast path | 23 |
| load: package callbacks | 13 |
| the definition-time check: compiling | 11 |
| the definition-time check | 3 |
| the member check (the library's hook) | 2 |
| the member check (the library's hook): inferring | 2 |
| definitions | 1 |
| the harness (set-up, `_` phases) | 188 |
| exit | 100 |
| profile samples (classed) | 42681 |

Phases, median of the unprofiled runs: ms (compiling, of it again; the collector) and the classes of 5 % or more:

- **nd-H**
  - the whole workload: 41763.7 ms (compiling 36667.7, again 435.0; gc 1075.7, 3888 MB) | code generation 27030; inference 6612; compiling while inferring 2335

