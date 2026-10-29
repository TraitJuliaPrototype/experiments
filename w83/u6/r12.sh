#!/bin/bash
# U6 (E-252), R12: P's image is written while Xs has no extension; then Xs gains XsSpExt
# (Project.toml [weakdeps]/[extensions], ext/XsSpExt.jl, Pkg.resolve). Is P's image used as it is?
cd "$(dirname "$0")"
ROOT=../../..; JL="$ROOT/experiments/tools/jl --name w83u6"; J=$ROOT/julia-1.13/julia
python3 gen.py R12 && rm -rf arr/R12/env
$JL $J --startup-file=no run.jl R12 parallel P
X=arr/R12/pkgs/Xs; S=$(grep '^uuid' arr/R12/pkgs/Sp/Project.toml | cut -d'"' -f2)
printf '\n[weakdeps]\nSp = "%s"\n\n[extensions]\nXsSpExt = "Sp"\n' "$S" >> $X/Project.toml
mkdir -p $X/ext && printf 'module XsSpExt\nimport Xs, Sp\nXs.ismember(::Sp.Ty) = true\nend\n' > $X/ext/XsSpExt.jl
$JL env JULIA_PKG_OFFLINE=true $J --startup-file=no --project=arr/R12/env -e 'using Pkg; Pkg.resolve(; io=devnull); println("RESULT R12 resolved: ", Pkg.dependencies()[Base.identify_package("Xs").uuid].name)'
echo "RESULT R12 --- after adding the extension: keep (no precompile) ---"
$JL $J --startup-file=no run.jl R12 keep P
echo "RESULT R12 --- after adding the extension: Pkg.precompile() ---"
$JL $J --startup-file=no run.jl R12 update P
