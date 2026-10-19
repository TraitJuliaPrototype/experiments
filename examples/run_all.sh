#!/bin/bash
# Run every example and framing case, one Julia process at a time (each takes the shared lock),
# logs under examples/logs/. Usage: examples/run_all.sh [name-filter]
# First, once: julia --project=examples/env -e 'using Pkg; Pkg.offline(true); Pkg.resolve()'
# (HShapes was added to the Manifest by hand; resolving refreshes its project hash).
cd "$(dirname "$0")"
E=$PWD; F=$E/../facts/framing; L=$E/logs; mkdir -p $L
TDE_ENV=$E/../../TraitDifferentialEquations/scripts/env
run() {  # name, dir, env vars…, -- julia args…
    local name=$1 dir=$2; shift 2
    [[ -n "$FILTER" && "$name" != *$FILTER* ]] && return
    local vars=(); while [[ $1 != -- ]]; do vars+=("$1"); shift; done; shift
    (cd $dir && env "${vars[@]}" $E/jl.sh "$@" > $L/$name.log 2>&1)
    echo "$(tail -1 $L/$name.log)   $name"
}
FILTER=$1
run inval-plain        $F X=1 -- inval_cases.jl
run inval-facts        $F JULIA_COMPILE_BY_FACTS=1 -- inval_cases.jl
run vararg-plain       $F X=1 -- vararg_splat.jl
run vararg-facts       $F JULIA_COMPILE_BY_FACTS=1 -- vararg_splat.jl
run s9-default         $F X=1 -- --project=$E/env s9_extension.jl
run s9-strict          $F JULIA_TW_STRICT=1 -- --project=$E/env s9_extension.jl
for o in after before prompt-after prompt-before binding; do
    run pirate-$o-default $F X=1 -- --project=$E/env pirate_tiers.jl $o
    run pirate-$o-strict  $F JULIA_TW_STRICT=1 -- --project=$E/env pirate_tiers.jl $o
done
run g1_16              $F X=1 -- --project=$E/env g1_16_dynamic_world.jl
for o in after before; do
    run dual-$o-default $E/strict JULIA_LOAD_PATH=$TDE_ENV:@stdlib -- dual_pirate.jl $o
    run dual-$o-strict  $E/strict JULIA_TW_STRICT=1 JULIA_LOAD_PATH=$TDE_ENV:@stdlib -- dual_pirate.jl $o
done
for c in nodelegate delegate staticarrays; do
    run split-$c        $E/strict JULIA_TW_STRICT=1 -- --project=$E/env split_core.jl $c
done
run extension-glue     $E/extension X=1 -- --project=$E/env glue.jl shapes-first
run extension-glue-geomfirst $E/extension X=1 -- --project=$E/env glue.jl geom-first
run heterogeneous      $E/heterogeneous X=1 -- --project=$E/env collections.jl
run errors             $E/errors X=1 -- --project=$E/env definition_errors.jl
run warnings           $E/warnings X=1 -- --project=$E/env teach.jl
run redefinition       $E/redefinition X=1 -- --project=$E/env prompt.jl
run ahead              $E/ahead X=1 -- --project=$E/ahead/env check.jl
run imageptr           $E/imageptr X=1 -- --project=$E/imageptr/env check.jl
