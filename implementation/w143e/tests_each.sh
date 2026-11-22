#!/bin/bash
# W-143e: Base's tests one file per run (tests.sh), one after another:  TREE=<tree> bash tests_each.sh <label> <test>...
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; L=$1; shift
for t in "$@"; do bash tests.sh $L-$(echo $t | tr / _) $t > /dev/null 2>&1; done
echo TESTSDONE
