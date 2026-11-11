# W-140's small cases: a membership invalidates as a method does

W-140 (`writeup/record/todo.md`) is checked by the gates, the library's tests and small cases, each of
seconds. The rounds over the ports and sessions wait for the conceptually complete state of the
prototype. Registry row: `writeup/record/experiments.md` E-365.

## The cases

| File | What it shows | Gate |
|---|---|---|
| `abstract_main_loaded.jl` | An abstract type against a trait, with `Main` marked as loaded: is "no subtype of `AbstractVector` is a `PX`" settled though `Vector{Int}` is a member? | `n2_open_abstract`, `n20_unmet_lookup` |
| `image_then_method.jl`, `PlainF/`, `PlainG/` | Code in a package image, compiled where its callee had no method at a trait. Then a membership. Two orders: the method at the trait before the image loads, or after | `n25_image_before_set_method` |
| `callable_late_method.jl` | A compiled caller passes a function where a method at `Callable` does not match; the function then gains the method | `n26_callable_late_method` |
| `comp_which.jl` | Which instance a later member's load ends in E-358's composition (`../w134/comp/`) | `n27_invariant_parameter` |
| (gate only) | A caller at `Any` or at an abstract argument, and the wide instance of another method, when a new type joins | `n28_wide_caller` |
| `load_invalidations.jl` | What the library's load invalidates in a fresh session without a prompt: the log's entries and code instances | — |

## How to run

```
source ../../../env.sh
J=../../../julia-unified/julia
$J --startup-file=no --project=.. abstract_main_loaded.jl
$J --startup-file=no --project=.. image_then_method.jl method-first     # or image-first
$J --startup-file=no --project=.. callable_late_method.jl
(cd ../w134/comp && JULIA_LOAD_PATH="$PWD/pkgs/trait:$PWD/../env_lib:@stdlib" ../../../../julia-unified/julia --startup-file=no comp.jl trait 3)   # one order of E-358
(cd ../../../TraitWorld-unified && ../julia-unified/julia --startup-file=no --project=. ../experiments/unification/w140/load_invalidations.jl)
```

## Results, 2026-11-11

One run each; the outputs do not vary. Product setting, load 7 to 18 of 128 cores.

| Case | Before | After |
|---|---|---|
| An abstract type against a trait (`unified` 1b2f0a9e1e, `Main` marked loaded) | `final(AbstractVector, PX)` is 1 though `Vector{Int}` is a member; `g(Int[1])` gives `:any`, the wrong method. The cause: a component of `All{AbstractVector{T}, PX} where T` was tested with its variable free | 0; `g(Int[1])` gives `:px` |
| Image code, the method at the trait before the image loads (`unified` 1b2f0a9e1e) | after the membership `h(S())` gives `:any`: **stale**. The image's code held no guard and no cell, and validation saw the same match | `:x` |
| Image code, the method after the image's load | `:x` (the method's insertion invalidated the caller) | `:x` (the membership does) |
| A call cached before a membership, at a method `f(c::C) where C <: X{T}` (`unified` 1b2f0a9e1e) | `:any` after the membership, at the prompt and through a compiled caller without its guard: the method was indexed under no set | `:setc` |
| A function passed where a method at `Callable` does not match, then its method (the build without guards, before the edge) | `:any`: stale | `:callable` |
| E-358's composition, the trait packages, two orders (seeds 0 and 3), one pass (`unified` a2ea2aff32, the first build with the walk invalidating) | **19 instances ended, one at each later member's load;** 141 own instances at the end against 160; 17 ms of compilation at each member's first use against 9. The core's `total(v::Vector{Shape})` and `work` were replayed by the walk's conservative path, which ended every instance of a method that names the trait inside a parameter | **0 ended, 160 instances,** 8.8 ms at each member: E-358's counts of 2026-11-10. A trait as an invariant parameter is not replayed |
| A new type joins; a caller at `Any`, one with an abstract argument, and `f(::Any)`'s instance compiled at `Any` (`unified` a2ea2aff32) | all three ended, though their calls matched the trait's method before and after | valid; the caller and the instance at the member's own type are ended |
| The library's load, a fresh session without a prompt (TraitWorld's image built; `load_invalidations.jl`, with `nowalk` for the control) | 24 log entries, 0 code instances, with the walk not invalidating (`nowalk`) | 65 log entries, 0 code instances |

"After" is `unified` a19d937eaa, TraitWorld 4718b6e (`writeup/design/julia-changes.md`, rows 101 to 103). Logs: `logs/`.

## Reading

- **Three of the five were wrong answers the guards hid or did not reach.** The image case predates W-140: under "a membership invalidates nothing" the image's code had no guard to open.
- **One mechanism now answers all of them:** a membership replays the trait's methods at the member, as if each were inserted at the member's type, and invalidates the callers whose selection changes. A caller holds the ordinary dispatch edge, in a session and in an image alike.
- **A membership adds no method.** Replayed as an insertion, it first ended what a new method would end: every caller at a wide signature. The two refinements keep what the membership cannot change: a call that matched the trait's method before, and a method that names the trait as an invariant parameter. The composition of twenty packages then counts as it did when a membership invalidated nothing.
- **The load's cost is not measured here** beyond the count above. The rounds are listed in the work queue.
