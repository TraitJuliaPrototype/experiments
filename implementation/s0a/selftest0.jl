# E-261's self-test, step 0: three callers of three callees, compiled
@noinline g1(x) = x + 1          # replaced below by a method with the same result type: f1 kept
f1(x) = g1(x) * 2
@noinline g2(x) = x + 1          # replaced by a method with another result type: f2 not kept
f2(x) = g2(x) * 2
g3(x) = x + 1                    # inlined into f3: a code edge, f3 not kept
f3(x) = g3(x) * 2
h1(x) = f1(x) + 1                # a caller of a kept caller: never invalidated with the slot (counted in the tree)
f1(1); f2(1); f3(1); h1(1)
