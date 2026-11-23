#!/usr/bin/env python3
# The whole series' table for the README (seventh part) from logs/k-series.tsv and the checks of each commit.
import sys
part = {}
names = ("P01 P02 P03 P04 P05 P06 P07 P08 P09 P10 P11 P12 P13 P14 P15 P16 P17 P18 P20 P21 P22 P23 P24 P25 P27 "
         "F0 F2 F1 F3 F4a F4b F4c F5 S1 F7 F8 F6 F9 F10 F11 F12 E7 row179 "
         "T1 T2a T2b T2c T2d T3 T4 T5 T6 T7 T8 T9a T9b T9c T10 T15 T11 T12 T13 T14 T17 S3 T16a T16b T16c").split()
check = {}
for n in names[:18]:
    check[n] = "stack (w19-stack); see the first part"
for n in "P11 P12 P14 P15 P16 P17 P18".split():
    check[n] = "alone (first part)"
for n in "P20 P21 P22 P23 P24 P25".split():
    check[n] = "stack (w19-stack-v2, sixth part's build 1)"
check["P27"] = "in the head (build 1); alone: parsed"
for n in "F0 F1 F5 F7 F6 F9 F10 F11 F12".split():
    check[n] = "in the facts head (third/fourth part)"
check.update({"F2": "alone (second part)", "F3": "alone (second part)", "F4c": "alone (= F4, second part)",
              "F8": "alone (the facts head)", "S1": "alone (as up/19)", "F4a": "**alone (build 12)**", "F4b": "compiled",
              "E7": "in w19-g-facts; the head", "row179": "in the head (build 1)"})
built = {"T1": 6, "T2c": 7, "T7": 5, "T9b": 8, "T14": 9, "T15": 10, "T12": 11, "T16a": 3, "T16b": 4, "T16c": 1}
for n in names[43:]:
    check[n] = f"**alone (build {built[n]})**" if n in built else "compiled"
for n in ("T2d", "T5", "T6", "T8", "T9c", "T10", "T11", "T13", "S3"):
    check[n] += "; built alone in an earlier part without this part's rows"
rows = [l.rstrip('\n').split('\t') for l in open(sys.argv[1])]
print("| Order | Part | Commit | Files | Added | Removed | Subject | Checked |")
print("|---|---|---|---|---|---|---|---|")
for (i, c, s, subj), n in zip(rows, names):
    f = (s.split(',') + ['0', '0', '0'])[:3]
    print(f"| {i} | {n} | {c} | {f[0]} | {f[1]} | {f[2]} | {subj} | {check[n]} |")
