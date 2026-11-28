#!/usr/bin/env python3
# W-19, eighth part: run as a rebase's `exec` after each pick; amends HEAD's message where its subject has an
# edit below: (old, new) replacements, each must apply once.
import subprocess
msg = subprocess.run(['git', 'log', '-1', '--format=%B'], capture_output=True, text=True, check=True).stdout
subj = msg.split('\n', 1)[0]
E = {
"Compiler, codegen, gf: fold no answer a membership could change": [
 ("  - the early constant evaluation of `isa`, `<:`, `>:` and `typeassert` with an argument that\n    names a set is left to the tfuncs, which ask the same.\n",
  "  - the early constant evaluation of `isa`, `<:`, `>:` and `typeassert` with an argument that\n    names a set is left to the tfuncs, which ask the same;\n  - a builtin's check by an empty intersection (`===`, a store's type test in `setfield!` and\n    `memoryrefset!`, a global's store, an opaque closure's argument test) and the optimizer's pruning\n    of a φ node's edge and of a `typeassert` (`may_intersect`).\n"),
 ("supertype's parameter\", \"a variable bound inside an invariant parameter compares its bounds with no\nentry\"",
  "supertype's parameter\", \"a variable bound inside an invariant parameter compares its bounds with no\nentry\", \"a builtin's check by an empty intersection about a set is no proof\""),
],
"gf, typemap: dispatch at sets, and the ambiguity report at a membership": [
 ("and a method pair with a method at a set is ordered in the\n  query's world rather than read from the interferences recorded at insertion.\n",
  "and a method pair with a method at a set is ordered in the\n  query's world rather than read from the interferences recorded at insertion, by every reader of a\n  method's list (the sort, the fully-covered and fully-ambiguous checks, the minmax search); a pair\n  of two closed signatures is read from the list as recorded.\n"),
 ("a closed type more specific than a set; a set below another\nmore specific; an intersection's match)",
  "a closed type more specific than a set; a set below another\nmore specific; an intersection's match), \"a listed interference is asked again in the query's world\""),
],
"gf, datatype: a membership invalidates as a method does; taking one back": [
 ("- The walk (`jl_membership_dispatch_walk`), run by the declaration under the world counter's lock\n  in the entry's world:",
  "- The walk (`jl_membership_dispatch_walk`), run by the declaration under the world counter's lock\n  in the entry's world, before the counter advances to it, as at a method's insertion: no task enters\n  the new world while code the membership ends is still valid there. For"),
 ("for every method at the set or at a set the member joins (the list by set),",
  "every method at the set or at a set the member joins (the list by set),"),
 ("- An entry at instances of its own variables",
  "- A pattern bounded by a set (`P{Z} where Z <: X`) puts under its own set the types whose\n  parameter the membership puts under the bound: the walk and the removal walk replay each such\n  pattern as a member (`membership_bounded_patterns`).\n- A place deeper than the walks follow (eight levels; a union's nesting is no level) is replayed at\n  the method's own signature for every member; a lower bound with parameters (`Tuple{S}`) holds the\n  member below its top and meets every member (`lower_bound_meets`).\n- A lookup asks whether a lower bound holds entries only of a method marked where it entered its\n  table (`Method.sig_lower_bound`, `jl_method_sig_lower_bounds`): nearly every method has none.\n- An entry at instances of its own variables"),
 ("\"a membership at every instance reaches a method at one instance\".",
  "\"a membership at every instance reaches a method at one instance\", \"a membership's walk replays a\npattern bounded by the set\", \"the walks reach past their depth and below a lower bound's top\"."),
],
"Compiler, gf, datatype: final negatives, and matches met at no type": [
 ("which records them. `Base.isambiguous`",
  "which records them. A lookup at a set that drops a method by an empty intersection a membership\ncould undo records the pair's absence (`ml_matches_dropped`, the drops' cells): a call compiled at\nthe set selects the member's own method once the membership holds. `Base.isambiguous`"),
 ("`new`'s field\ntest that is not proved,",
  "`new`'s field\ntest and a store's type test (`setfield!`, `memoryrefset!`) that are not proved,"),
 ("Test: test/subtype.jl, \"final negatives\",",
  "An opaque closure's call at arguments whose test about a set a membership could change is left to\nthe closure's own test when it runs; a positive through an entry records the entry.\n\nTest: test/subtype.jl, \"final negatives\", \"a lookup at a set records the pairs whose absence\ndropped a method\", \"a store's test about a set that inference did not prove is not consistent\",\n\"an opaque closure's call decides its test about a set only with a record\","),
],
"staticdata, datatype: memberships in package images": [
 ("Then the membership's walk and the ambiguity report run as at a\ndeclaration.",
  "Then the membership's walk and the ambiguity report run as at a\ndeclaration, in the entries' world before the counter advances to it."),
],
"datatype, gf: strict mode refuses a membership that makes an ambiguity": [
 ("also the methods whose lower bound the member meets, each at its own\nsignature)",
  "also the methods whose lower bound the member meets, each at its own\nsignature, and each pattern bounded by the set at the member, as the walk replays it)"),
 ("Test: test/subtype.jl, \"a strict mode\".",
  "Test: test/subtype.jl, \"a strict mode\", \"what a membership would replay names the patterns bounded\nby the set\"."),
],
"Core, gf: the kept forms `Dynamic{X}`, `Compiled{T}`; arguments at a set": [
 ("(`chain_has_set_bounded_pattern` in `jl_membership_final`).",
  "(`jl_chain_has_set_bounded_pattern` in `jl_membership_final`), and a lookup that drops a method at\nsuch a type records the absence at `Any`."),
],
}
if subj in E:
    for old, new in E[subj]:
        assert msg.count(old) == 1, (subj, old[:60])
        msg = msg.replace(old, new)
    subprocess.run(['git', 'commit', '-q', '--amend', '-m', msg.rstrip('\n') + '\n'], check=True)
    print('amended:', subj)
