# E-358: composition at scale, twenty small trait packages in random load orders

W-134 (d), E-109's form, on the unified build. Registry: E-358 in `writeup/record/experiments.md`. Current numbers: `writeup/design/evidence.md` §1.

**The question.** Twenty packages each add a member to one trait. Does a later member's load end code compiled for earlier ones? Do the counts depend on the load order? What does a session compile per added member?

**The packages** (`gen.jl`; generated into `pkgs/`, not committed).
- `CompCore`, a trait module: the trait `Shape` (`area`, `label`), a loop over `Vector{Shape}` (`total`), and a per-member step under `compiled_for` (`work`).
- `CompM01` to `CompM20`, trait modules: a struct, its `@implement Shape`, a function of its own, and its image's work.
- The plain twin: `PCore` (an abstract type `Shape`, generic functions) and `PM01` to `PM20` (subtypes and methods).

**The session** (`comp.jl <kind> <seed>`): the core, then the twenty in the seed's order (seed 0: 1 to 20). After each load the member's value joins the vector and the work runs on the members so far. Counted: the valid instances of the twenty-one packages a load ends; the own instances the work compiles; the work's time and compile time.

## How to run

```
source ../../../../env.sh
bash run.sh e358        # generate, then seeds 0..4 per kind: a warm-up pass and two passes; logs/e358.log
JULIA_LOAD_PATH="$PWD/pkgs/trait:$PWD/../env_lib:@stdlib" julia-unified/julia probe.jl trait   # what a member's first use compiles; the core's work alone
```

## Results (2026-11-10)

Build: `unified` 36b653bb3b, TraitWorld-unified 048c44e. Product setting, strict mode off, one thread. Five orders, two passes after a warm-up; the counts are identical in all ten runs of a kind. Load 9–15 of 128 cores (others' jobs). Measures idiomatic trait code against its plain twin.

| | trait packages | plain twin |
|---|---|---|
| instances ended by a later member's load, in a session | **0**, in every order | 9: 3 at each of the 2nd, 3rd and 4th member, in every order |
| own instances at the end | 160, all facts code; the same in every order | 123; the same in every order |
| own instances the work compiles after a load | 0 at every member | 3, 5, 4, 4, then 1 per member |
| compile time at a member's first use | 8.3–8.6 ms at every member from the second (13.5 ms at the first, the script's own code) | 30, 31, 18, 39 ms at the first four; 6.8–7.2 ms after |
| the core's work on twenty members, repeated (`probe.jl`, the least of 2,000) | 2.9 µs | 5.2 µs |

- The digest (the work's sum) is the same in every order and kind.
- **What the trait session compiles per member** (`logs/e358-probe.log`): two instances in Base, `Base._split_pointer` and `Base._SplitTarget` for (`area`, the member's type): the pointer through which the loop in `total` calls a member that joined after the loop was compiled (compiler §7.2, §7.3). 8.3–9.4 ms each time, in every session: no image holds it. With one member loaded none is made.
- **What the plain session compiles per member:** `step` for the member's type; and at the second to fourth member the core's `work`, `total` and `step` at `Shape` again, which the new methods of `area` and `label` ended.
- The line "the work repeated" in `e358.log` includes the session script's own dynamic calls into each member's module; the core's work alone is `probe.jl`'s number.

**Reading.**
- Composition holds the guarantee: no load ends an instance, and the counts do not depend on the order.
- The cost of composition is constant per member, about 9 ms at its first use per operation called at a run-time site, paid again in each session (GT-7 and the caching axis G-3; `writeup/open-issues.md` §1).

**Found on the way.** A membership is visible from the world of its load: the session script's `push!(v, x)` in a loop compiled before the load raised "Cannot convert an object of type CompM01.M to an object of type CompCore.Shape … The applicable method may be too new" until it ran in the latest world. Plain Julia's subtyping has no such case; the message names the world.

## Logs

`logs/e358.log`, `logs/e358-probe.log`.
