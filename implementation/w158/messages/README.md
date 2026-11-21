# The library's messages against the form of a message (W-158, second part; open issue 235)

**The rule** (writeup/reference/traits.md §11.3, "The form of a message"): a signature prints as a call; the
compiler's tuple type appears in no message; a fault names what is used. **The pattern:** a message built by
interpolating a signature, a method's name or a method instance prints the compiler's form: `Tuple{typeof(f), …}`,
a keyword body's or a closure's generated name (`#f#3`, `var"#g##0#g##1"`), the library's own functions
(`TraitWorld._callable_met`). This tool finds every instance in the messages the library computes.

## What it does

- `capture.jl`, included before a script: records every message the script computes with `sprint(showerror, e)`
  (the library's tests and the documentation's examples compute each message they check so), and every warning that
  reaches the global logger. It pirates `Base.sprint` at `showerror` in its own process only.
- `run.sh <label> [<library tree>]`: runs, one process at a time, the library's tests (`test/runtests.jl`), the
  documentation's examples (`intro`, `tutorial`, `strict`, from `../../../docs-examples/`) and `cases.jl`, each
  with `capture.jl`; then `scan.py`.
- `cases.jl`: errors no test and no example shows: the bounded check at each form of a signature (one trait
  argument and two, a keyword method, a `where` variable, a parametric trait, a vararg, a closure, an undeclared
  field), the kept forms' errors (a box's undeclared field, a `@const` field written, a non-member, a box without
  parameters, `withfields` and `like`), an operation outside its signature at a box and at a wrapper, `Callable`'s
  four refusals, `@enforce_fully_typed`, and the declarations' errors.
- `scan.py <records> [<outputs>]`: each distinct message, and each `WARNING:` line Julia's runtime prints itself,
  matched against the forms:
  - **tuple type:** `Tuple{typeof(`;
  - **generated name:** `var"#`, `#self#`, a forwarder's (`#forwarder#`, `#entry#`), a gensym (`##arg#12`), a
    keyword body's or a closure's (`#f#3`, `#g##0`);
  - **compiler object:** `MethodInstance for `, `CodeInstance`, `Core.Dynamic`, `Core.Compiled`;
  - **library internal:** `TraitWorld._name`;
  - **box or wrapper type:** `Dynamic{`, `Compiled{`. Listed for reading, not counted as a defect: a message may
    name a kept form the user wrote, or the box the bounded check reads, which its head introduces.

## How to run

```sh
source env.sh                                   # the workspace's; then a depot of your own (playbook §2)
bash experiments/implementation/w158/messages/run.sh <label> <library tree>     # about 45 s
```

Logs: `../logs/b-messages-<label>.tsv` (the records), `-<run>.out` (each run's output, with the library's
commit in its first line), `-scan.txt` (the findings, then the counts).

## Results, 2026-11-21

Julia `julia-next` f5328f94c5; the library `wt/w158b-tw` (branch `w158b`). Load 3 to 4 of 128.

| Label | Library | Distinct messages | Tuple type | Generated name | Compiler object | Library internal | Box or wrapper type (read) |
|---|---|---|---|---|---|---|---|
| `before-ccd6c48` | ccd6c48 (`unified` 9d4f782 and `withfields` on a kept form) | 94 | **13** | **2** | 0 | **1** | 25 |
| `after-piece2` | e32d443 (the messages print a signature as written) | 102 | 0 | 0 | 0 | 0 | 33 |

The corpus of the second row has 8 more messages: the tests of the bounded check's message added to
`test/messages.jl`.

**What the 16 findings were, all the library's:**
- the bounded check's `TraitUseError` (`src/classify.jl`): `colsum is declared bounded, and is not bounded at the box
  (Tuple{typeof(Main.Broken.colsum), Dynamic{ColTable}})` (11 messages); a keyword method named by its body
  (`#cscaled#1`) and a closure by its type (`#cmapper##0`, `var"#cmapper##0#cmapper##1"`); its fault lines printed
  the argument types without `::` (`sum(Dynamic{ColTable}) reaches iterate(Dynamic{ColTable})`);
- `NotFullyTypedError` and the fully typed report (`src/fullytyped.jl`): `not fully typed: Tuple{typeof(etotal),
  Holder}` (2); by the same code, not provoked by the corpus: `verify_main`'s report head and `BuildError`
  (`src/build.jl`, `… is not fully typed at Tuple{Int64}`);
- a pirate's report (`src/report.jl`, through `_code_name` in `src/strict.jl`, which strict mode's `PirateError`
  shares): `It ended 4 instances: TraitWorld._callable_met, TraitWorld._callable_entry_check, Main.StrictLib.sq`.

**The fix, at the rule:** a signature prints as a call (`_callform`), a method as it is written (`_written_method`,
`src/errors.jl`: a keyword body as its function with its keywords, a closure as `(t::CTab) -> … in cmapper`), code by
the name its user wrote, the library's own instances counted, not named. TraitWorld e32d443.

**Box or wrapper types after the fix (33), read one by one:**
- 21 `TraitUseError`s: the box the bounded check reads, named by the head (`read with \`t\` in a box,
  \`Dynamic{ColTable}\``) and at the call it reaches (`iterate(::Dynamic{ColTable})`, as traits §7.3 writes it);
- 4 `MethodError`s at a kept form the user wrote (`ccol(::Dynamic{CTab}, ::Float64)`); `Dynamic{X} needs the
  trait's parameters` (Core's, at `Dynamic{CVec}` written bare); `@trait_module`'s advice, which writes
  `Dynamic{Model}(m)` as the fix;
- **6 in Julia's own message, not fixed:** `MethodError`'s "Closest candidates" list the forwarding methods the
  library defines at the wrapper's family, where the user wrote no wrapper: `sz(!Matched::Compiled{<:Sized2})`,
  `col(!Matched::Compiled{<:ColTable}, !Matched::Int64)`, `mscale(!Matched::Compiled{<:MScalable}, …)`,
  `applyc(!Matched::Compiled{Z} where Z<:Callable{Tuple{Int64}, Int64}, ::Any)` (two messages),
  `cm(!Matched::Compiled{Z} where Z<:Callable{Tuple{Float64}, Float64}, ::Float64)`. Julia's
  `show_method_candidates` has no way for a package to leave a method out.

**Seen beside the forms:** a method at a vararg of members, `call(ts::CTab...) = sum(t -> sum(t), ts)`, is accepted
in a `bounded` scope: `box_signature` boxes no `Vararg` position, so the method is not read at the box.
