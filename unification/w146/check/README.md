# E-391: the checks' own code compiled in each session (W-146, items 9 and 3)

The question: E-388 found 2.10 s of the first edit's 2.57 s compiling the definition-time check's own code. Why, and can an image hold it?

- **The cause:** the library ran the check's inference in the latest world. There a load's methods end the compiler's instances (610 in each load's log), and the session compiled them again.
- **The fix:** the check runs in the world Julia's own inference runs in (`Base.invoke_in_typeinf_world`; TraitWorld `src/classify.jl`, `src/implement.jl`), and the compiler's bootstrap compiles the check interpreter's entries there (`Compiler/src/bootstrap.jl`). The list of entries came from a session's trace (`--trace-compile`) of the first check.
- Without the bootstrap's entries the first edit took 8.5 s, with the three static entries 4.1 s, with the traced ones 0.65 s.

## Results, 2026-11-14

`unified` with the bootstrap's entries against 8fccf1e182; TraitWorld with the change against 2072e75; product setting, strict mode off, one thread; a warm-up and 2 fresh processes; load 1 to 2 of 128. Current numbers: [the evidence](../../../../writeup/design/evidence.md).

| | before | after |
|---|---|---|
| an edit of `summarize`, the first (E-388's session) | 2.57 s | 0.64–0.67 s |
| the same edit again | 0.44 s | 0.48–0.50 s |
| the edit's definition in E-379's prompt row | 2.64 s | 0.70 s |
| `sys.so` | 215.0 MB | 219.6 MB |

Logs: `../../w145/profile/logs/table-check.log`, `../../w134/logs/e391.log`, `../../w120/logs/sessions-r391.log`.
