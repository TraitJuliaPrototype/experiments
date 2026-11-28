#!/bin/bash
# W-19 eighth part: a lane of part builds, one after another in TREE: lines "<n> <label> <commit> <tests...> [| tw]"
#     TREE=wt/w19-check bash l-queue.sh <queue file>
while read -r n label c rest; do
  [ -z "$n" ] && continue
  tests=${rest%%|*}; extra=$(echo "$rest" | grep -q '| tw' && echo tw)
  bash "$(dirname "$0")/l-parts.sh" "$n" "$label" "$c" "$(echo $tests)" $extra
done < "$1"
