# doclint: what the documentation rules forbid, counted

The tool of the documentation clean-up (W-162; [the plan](../../../writeup/plans/2026-11-18-documentation-cleanup.md) §2 and part 0). It counts, per current document of the design repository, what the plan's rules R1 to R4 forbid. The clean-up ends when each count is zero or a listed exception.

## Run

```
python3 experiments/tools/doclint/doclint.py                      # the table
python3 experiments/tools/doclint/doclint.py --details earlier-build   # every hit of one check
python3 experiments/tools/doclint/doclint.py --details dates --file state.md
```

It reads files only: no Julia, no network. Python 3, standard library.

## The checks

| Column | Check | Rule |
|---|---|---|
| `links` | a relative link whose file does not exist (anchors are not checked) | — |
| `earlier` | names of the earlier build (`julia-1.13`, `earlier build`, TraitWorld `main`, …) and "unified build" | R1 |
| `history` | history words: `no longer`, `superseded`, `formerly`, `Earlier:`, `replaced by`, `decided`, `built on`, … | R2 |
| `dates` | a date `20yy-mm-dd` | R2 |
| `iter` | a comparison against an earlier iteration (a word list: `against the baseline`, `the attribute's 7`, `prototype-2026-11`, …). Every hit is read by hand | R3 |
| `to-arch` | a link into `plans/`, `reviews/`, `explorations/` or `attic/`, but for the live plans and reviews (`LIVE` in the script) | R4 |
| `old-E` | experiment IDs cited that are not in the current registry. Until the registry is split: IDs up to E-261 | R3, R4 |
| `commits`, `W-n`, `D-n`, `branch`, `user/mine` | in the references only: commit hashes, work items, rows of a plan, branch and tree names, the user's words and "mine" | R2 |

**Which documents.** `STRICT` and `REFERENCES` in the script: the front doors, the goals, the state, the rationale, the glossary, `intro/`, the references, the evidence, the inventory, the open issues, the index, the queue, the registry. The documents that are about the history by their purpose (`HISTORY`: the alternatives, the lessons, the decision log, the design history) have their links checked and nothing else.

**What a hit means.** A count is a place to look, not a verdict. "decided" in a sentence about how dispatch is decided is no history. Exceptions are listed in the last log.

## Logs

| Date | Design repository | Log | Totals |
|---|---|---|---|
| 2026-11-18 | 59c6f97, before the clean-up | [`logs/2026-11-18-before.txt`](logs/2026-11-18-before.txt) | links 0, earlier 640, history 348, dates 3,025, iter 89, to-arch 825, old-E 327; in the references: commits 727, W-n 294, D-n 102, branch 521, user/mine 196 |
