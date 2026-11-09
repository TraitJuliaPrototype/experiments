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
