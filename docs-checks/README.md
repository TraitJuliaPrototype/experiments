# Checks of the design repository's documents

Tools that find every instance of a documentation pattern that recurs (CLAUDE.md: "A failure names a pattern").
Each is a report: it changes nothing.

## `check_links.py`: links, anchors and section citations

Adopted from [the documentation review of 2026-11-09](../../writeup/reviews/2026-11-09-documentation-consistency.md) (M5), which found dead anchors and stale section numbers in current documents; the review of 2026-10-26 of `lowering.md` had found 94 stale citations.

```sh
python3 -I experiments/docs-checks/check_links.py writeup          # current documents
python3 -I experiments/docs-checks/check_links.py writeup --all    # with reviews, plans, session notes, the attic
```

It checks, for every Markdown file outside the history folders:
- every link `[t](path#anchor)`: the file exists, and the anchor matches a heading (GitHub's slugs) or an `<a id="…">`;
- every prose citation `traits §7.5`, `compiler §4.8`, `facts §10`, `lowering §3`: a heading so numbered exists. A citation that is a link's text is checked against the linked file, so a citation of an attic reference keeps the attic's numbering;
- inside a reference, a bare `§x.y`: the page's own heading.

One line per problem, `file:line: kind: detail`; the count on stderr.

Run it before a commit that renumbers a reference's sections. Hits in rows that are history by content (the closed open issues, the decision log, the experiments registry, `alternatives.md`, the work queue's done rows) cite the numbering of their day and stay.

### Results

| Date | Build of the documents | Problems | Outside history-by-content rows |
|---|---|---|---|
| 2026-11-09 | before the review's fixes | 112 (the review's first version, without the link rule) | 37 |
| 2026-11-09 | after the fixes (design repository, this date) | 48 | 3, dated rows of `evidence.md` and `record/INDEX.md` citing their day's numbering |

## `check_quotes.py`: the ports' code a document quotes

Found on 2026-11-11 by [the review of the introduction and the rationale](../../writeup/reviews/2026-11-11-intro-and-rationale.md) (M2): `intro/porting.md` quotes the ports' code by file and line, and the ports move under it.

```sh
python3 -I experiments/docs-checks/check_quotes.py writeup/intro/porting.md
```

For every citation `path/file.jl:LINE` (in prose, or as a comment on a quoted line in a code block; `# :LINE` reuses the last file; `…/file.jl` is found by its suffix among the ports' tracked files):
- the file exists and has the line;
- a quoted line is the file's line, compared without runs of whitespace.

One line per citation: `OK`, `MOVED to line n`, `DIFFERS`, `NOLINE`, `NOFILE`, `AMBIGUOUS`, or `CITED` with the file's line, for a prose citation that quotes nothing on its own line (to be read). The count of problems on stderr; exit status 1 if any. Run it when a port's source files change, and before a commit of the guide.

### Results

| Date | Ports | Citations | Problems |
|---|---|---|---|
| 2026-11-11 | forks ddc20f6, TraitDifferentialEquations 6658c65, TraitMakie c9e294b, NetworkDynamics d8c9c49 | 23 | 3 found by the check (`core.jl:97` and `frontend.jl:62` a line off, `coreloop.jl:154` quoted without its `@inline`) and one by reading a `CITED` line (`TraitMakie.jl:229`, now 232); corrected, 0 left |

## `check_tables.py`: every row with its table's number of cells

Found on 2026-11-10: the scripts that write an experiment's outcome split a registered row (`| where | | |`) into five cells, not six, and wrote two outcomes into the status cell, losing the where cell (E-339, E-340). The same check then found the work queue's rows W-72 to W-130 under the three-column table of the items carried over, so they rendered broken, and julia-changes' rows 73 to 85 without their *Kind* cell.

```sh
python3 -I experiments/docs-checks/check_tables.py writeup/record/*.md writeup/design/*.md writeup/reference/*.md writeup/open-issues.md writeup/state.md
```

One line per row whose cell count differs from its table's header, `file:line: n cells, the header has m: <ID>`; the count on stderr. A `|` inside a code span, or escaped, does not split a cell. Run it after a script writes rows.

### Results

| Date | Build of the documents | Rows | Left |
|---|---|---|---|
| 2026-11-10 | before the fixes | 90 | — |
| 2026-11-10 | after the fixes (E-339, E-340, E-329 to E-331, the queue, julia-changes) | 14 | the registry's E-190, E-233, E-234, E-238, E-241 (a cell short since they were written); 8 rows of the record index's reviews without the column of what was done; one row of `evidence.md` §2 in two cells |
