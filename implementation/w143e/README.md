# W-143e: what the census's patches left: callees named by instance, the sets in a lower bound, the unions of another shape (E-541)

The work queue's W-143 ([the work queue](../../../writeup/record/todo.md)), after its patches (E-540, [`../w143d/README.md`](../w143d/README.md)) and its census (E-535, [`../w143c/README.md`](../w143c/README.md)). Four pieces:
1. a callee named by its MethodInstance where that instance had no code when the caller finished (open issue 219; `_promote_typesubtract` below `promote_typejoin`): every such edge in the three sessions, by callee; the record's fault or a missing declaration;
2. the sets in a type variable's lower bound, for a positive answer through an entry (compiler C-161): a probe, then a fix if it shows a wrong answer;
3. the unions of another shape (compiler C-160): what each edge is, and what compiler §1.2 says of it;
4. the census before and after, by group.

## The registry's row (E-541), written before the run

- **The question.** What is left below a port's code after the census's patches: which callees are named by their instance where it had no code, and is the fault the record's or a missing declaration; does a positive answer through an entry, about a set that occurs only in a variable's lower bound, outlive its entry (C-161); what shape are the unions still unsplit (C-160)?
- **The baseline.** The head before (`next` bfaf484f55, `julia-next/`) is a regression control for the share. Plain Julia (vanilla v1.13.2, `julia-vanilla/`) for each declaration's effect on the system image and on plain code.
- **What would change the design or the list of patches.**
  - The record's rule (compiler §3.1, §3.2: an edge names the callee's code where it exists when the caller finishes) not met for a reason inside the compiler (the order in an inference cycle, the compile queue): a fix at the rule, built where it is small; else its size, and the declarations stand in.
  - A callee compiled once (a `@nospecialize` argument) whose instance inference does not use: `Base.@nospecializeinfer` on it, a declaration of what already happens, a patch that stands without traits.
  - A positive answer through an entry, about types where the set occurs only in a lower bound, that compiled code keeps after the entry ends: a soundness defect (compiler §4.8), fixed with the probe as a test. No such case possible: C-161 is no hole, and the row says why.
  - An unsplit union whose splits are each one match at a fact: a record fix if it follows from compiler §1.2 and is small; a union whose splits match several methods each or are no facts: the section's matter, stated.
- **The setting.** Product setting, strict mode off, one thread, one fresh process per session; a depot of this item's own per Julia tree (`.julia-depot/agent-depots/w143e/<tree>` in front of the shared one), whose package images are written anew for each build; the machine's load before and after in each log. TraitWorld `unified` e2cb5d0, the forks a3a37d6, TraitDifferentialEquations 21a5aa5. Builds `WIDE=0` (4 cores), one after another, at most four, in the worktree `wt/w143-julia` on a branch `w143e` from `w143-v2` = `next` bfaf484f55.

## How to run

```sh
source env.sh                                           # TREE=julia-next by default; TREE=wt/w143-julia for the branch
TREE=<tree> bash run.sh <label> images                  # the package images of the three environments, once per build
TREE=<tree> bash run.sh <label> forks|facts|ode         # the census -> logs/<label>-<session>.log and .tsv; 1 to 2 minutes
TREE=<tree> bash run.sh <label> forks diag/mi_edges.jl  # the faults "a callee named by its MethodInstance", by callee
TREE=<tree> bash run.sh <label> forks diag/unionsplit.jl  # the culprits of the group "a top-level union"
TREE=<tree> bash run.sh <label> forks diag/culprit.jl Base.promote_typejoin …   # culprits up close
python3 compare.py <label> <label>                      # two censuses side by side, by group
```

- The tools are copies of `../w143d/`'s (`census.jl`, `census_lib.jl`, `run.sh`, `compare.py`, `diag/`, `motiv/lb_bit.jl`, `motiv/record.jl`), with the depot of this item; changes and new programs are named in the results.
- `envs/` are copies of `../w143d/envs/`.

## Results
