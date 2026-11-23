#!/usr/bin/env python3
# The seventh part's wording pass over the series' commit messages (W-19 §6): names a reader outside the project
# does not know are replaced by what they stand for. Applied by k-restack.py to every message it commits.
import re, sys

PATCH_NAMES = {
    "the patch `up/19`": "the patch that keeps a call's own signature in its dispatch backedge",
    "(the patch `up/19`)": "(the patch that keeps a call's own signature in its dispatch backedge)",
    "(the patch `up/20`)": "(the patch that infers `!==` once)",
    "`up/20` adds too": "the patch on `!==` adds too",
    "patch on the type joins, `up/03`": "patch on the type joins",
}
PHRASES = [
    ("Test: a facts-only copy of gate `f2_policy_flags`", "Test: outside Julia's suite, a facts-only copy of the design's gate `f2_policy_flags`"),
    ("(measured on the facts series, whose deep class carries the same\nclause: 240 instances of the system image against 4,610)",
     "(measured on a build that has both: 240 instances of the system image against 4,610)"),
    ("`typesubtract` gets the two gates the earlier part left out: no subtraction to\n`Union{}` through an entry, no negative.",
     "`typesubtract` now refuses the two folds the earlier commit left: no subtraction to\n`Union{}` through an entry, no negative."),
    ("so the compiler's gates treat it as a set,", "so the compiler's refusals to fold treat it as a set,"),
    ("an `invoke`\n  at a declared signature is not gated;", "an `invoke`\n  at a declared signature is not checked;"),
    ("an `invoke` at a declared signature is not gated;", "an `invoke` at a declared signature is not checked;"),
    ("the options word that the facts series adds", "the options word that an earlier commit adds"),
    ("(the fourth part's rule, which needs\nthe taking back)", "(the rule of \"inference asks memberships in the world it infers for\", which\nneeds the taking back)"),
    ("(the fourth part's rule, which needs the\ntaking back)", "(the rule of \"inference asks memberships in the world it infers for\", which\nneeds the taking back)"),
    ("(the second part's rule)", "(the rule of \"a membership is a supertype in the worlds it is in force\")"),
]

def gate_note(msg):
    # the first mention of the design's gates in the message says what they are
    m = re.search(r"\b(the )?(gates?) `", msg)
    if not m or "outside Julia's suite" in msg:
        return msg
    word = m.group(2)
    note = f"outside Julia's suite, the design's {word} `"
    return msg[:m.start()] + note + msg[m.end():]

SUBJECTS = {
    'base: type-introspection helpers read fields with getfield and call each other by invoke': 'base: introspection helpers read fields with getfield, call by invoke', "show: IOContext stores a property through ImmutableDict's own constructor by invoke": 'show: IOContext(io, k => v) builds its ImmutableDict by invoke',
    'reflection: run the native compiler in its world for an explicit NativeInterpreter': 'reflection: an explicit NativeInterpreter runs the compiler in its world',
    'Compiler: an invoke keeps the exact specialization when only a varargs tail is widened': 'Compiler: invoke keeps the exact specialization over a widened varargs tail',
    'gf: the per-call-site cache holds entries that match every type at their Any positions': 'gf: the per-call-site cache holds entries with Any positions as wildcards',
    'staticdata: an image keeps no external code specialized at a signature type without a hash': 'staticdata: keep no external code at a signature type without a hash', "generate_precompile: compile Base.infer_return_type's inference into the system image": "generate_precompile: compile Base.infer_return_type's inference", 'Core, Compiler: `!==` is inferred once, at `(Any, Any)`, and a call is matched at its own types': 'Core, Compiler: infer `!==` once and match a call at its own types', "base: the type predicates and the layout readers read a type's fields with `getfield`": 'base: type predicates and layout readers read fields with `getfield`', "base: the joins under `promote_typejoin_union` and a tuple's `eltype` read fields with `getfield` and call through `invoke`": 'base: getfield and invoke under promote_typejoin_union and tuple eltype', "base: the task code passes an exception and a payload at the callee's own signature": "base: task code passes a payload at the callee's own signature", "Core, Compiler: `TypeVar` and `UnionAll` are inferred once and matched at the call's own signature": 'Core, Compiler: infer TypeVar and UnionAll once, match calls at own types', "base: infer `_promote_typesubtract` and `fieldname`'s error path once, at the instance that runs": "base: infer `_promote_typesubtract` and `fieldname`'s error path once", 'julia.h, jltypes: fields for a per-method compile policy (`Method.facts`, `Module.facts`, a CodeInstance flag)': 'julia.h, jltypes: fields for a per-method compile policy',
    'lowering, module: `@compiler_options facts=true` and the method metas `:facts_boundary`, `:facts_always`': 'lowering, module: `@compiler_options facts=true` and the policy metas',
    'Compiler: the `nortsite` effect bit (no call dispatched at run time here or in a callee)': 'Compiler: the `nortsite` effect bit',
    'Compiler: a facts inference that infers a call only at a fact signature (`NativeInterpreter(; facts = true)`)': 'Compiler: a facts inference that infers calls only at fact signatures', "gf, codegen, builtins, interpreter: a call runs the callee's code of the caller's policy": "gf, codegen: a call runs the callee's code of the caller's policy", "Compiler, gf: a dispatch backedge keeps the call's own signature where the call reached a wider instance": "Compiler, gf: a dispatch backedge keeps the call's own signature", 'Compiler, gf: the G2 bit, set on a CodeInstance whose edges are facts at any depth': 'Compiler, gf: the G2 bit, on code whose edges are facts at any depth', "gf, module: `JULIA_COMPILE_BY_FACTS=1` compiles a session's own code by facts (a test bed)": 'gf, module: `JULIA_COMPILE_BY_FACTS=1`, a test bed for the facts policy',
    'Compiler, gf: fully typed mode, a check at the start of facts code that dispatches at run time': 'Compiler, gf: fully typed mode, a check at the start of facts code',
    'Compiler: a compile request takes the code of any equivalent cached entry, a compiled one first': 'Compiler: a compile request takes the code of an equivalent cached entry', "Compiler: a call's edge at a top-level union is split, each split with its own edge": "Compiler: split a call's edge at a top-level union", 'julia.h, jltypes: the layout for sets and memberships (`TypeName.memberships`, `Core.MembershipEntry`, `DataType.has_open_set`)': 'julia.h, jltypes: the layout for sets and memberships',
    'datatype, subtype: declaring a set and a membership, with its checks and its worlds': 'datatype, subtype: declaring a set and a membership', "subtype: a non-member's answers at a set without the walk, and reachability memoized per world range": "subtype: a non-member's answers without the walk; reachability memoized", 'Compiler, codegen, gf: inference asks memberships in the world it infers for, and folds no answer a membership could change': 'Compiler, codegen, gf: fold no answer a membership could change', "gf, typemap, subtype: dispatch at sets, a match's worlds through memberships, and the ambiguity report at a membership": 'gf, typemap: dispatch at sets, and the ambiguity report at a membership',
    'gf, datatype: a membership invalidates as a method does, and a membership taken back': 'gf, datatype: a membership invalidates as a method does; taking one back',
    'Compiler, gf, datatype: a membership is a method of `Core.implements`; answers folded through it hold an edge to it': 'Compiler, gf: a membership is a method of `Core.implements`',
    'Compiler, gf, datatype: final negatives, and a match met only at an intersection no type is in': 'Compiler, gf, datatype: final negatives, and matches met at no type', "gf, method, staticdata: hooks for a trait library at a definition, a deletion, a module's end and an image": 'gf, method, staticdata: hooks for a trait library',
    'datatype, gf: a strict mode for a trait library, which refuses a membership that makes methods ambiguous': 'datatype, gf: strict mode refuses a membership that makes an ambiguity', "Compiler, effects: the `trusted` effect, and the checks of a result a member's own code does not check": "Compiler: the `trusted` effect and the checks of an operation's result", "Compiler, datatype, gf: an operation's call split over its set's candidates, and the table of a call's targets": "Compiler, gf: an operation's call split over the candidates, then a table", 'Core, Compiler, jltypes: `Callable{A, S}`, the functions called with arguments of `A` that return an `S`': 'Core, Compiler: `Callable{A, S}`, functions called with `A` returning `S`',
    'Core, gf: the kept forms `Dynamic{X}` and `Compiled{T}`, and an argument typed by a set': 'Core, gf: the kept forms `Dynamic{X}`, `Compiled{T}`; arguments at a set', "Compiler: the definition-time check's interpreter (`DefinitionCheckInterpreter`) and its bootstrap entries": "Compiler: the definition-time check's interpreter", "module, lowering: the module's options word for the trait language's scope options is named `trait_options`": "module, lowering: name the module's trait options word `trait_options`", 'Compiler, datatype: a closed build counts the members of a set by use, and compiles in rounds': "Compiler: a closed build counts a set's members by use, in rounds", "Compiler: a closed build branches over a set's members where a call does not know its argument's member": "Compiler: a closed build branches over a set's members", "Compiler: a closed build's rules as a check in a session, and the verifier of an invoke that names its instance": "Compiler: a closed build's check in a session, and its verifier"}

def filter_msg(msg):
    first, _, rest = msg.partition('\n')
    first = SUBJECTS.get(first.strip(), first)
    msg = first + '\n' + rest
    for a, b in PATCH_NAMES.items():
        msg = msg.replace(a, b)
    for a, b in PHRASES:
        msg = msg.replace(a, b)
    msg = gate_note(msg)
    return msg

if __name__ == '__main__':
    sys.stdout.write(filter_msg(sys.stdin.read()))
