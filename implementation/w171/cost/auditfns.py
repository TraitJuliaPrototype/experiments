# W-171, fourth part (E-545): the samples of the audit's functions in plain code's session, per build, from
# prof-plain.jl's profiles: per function the mean samples whose stack holds it and where it is the leaf, for the load
# and the first work. A build is given as name=file,file,... (the phase's suffix `-load.tsv` / `-work.tsv` added).
#     python3 auditfns.py V=logs/prof-r1-V-1,logs/prof-r1-V-2 H=... N=...
import sys, re, collections
PAT = re.compile(r'lower_bounds_have|sig_lower_bounds|sig_has_open_set|method_in_interferences|listed_interference|'
                 r'has_key @|kind_meets|ml_matches_dropped|drop_position|names_open_set|may_intersect|'
                 r'negative_fold_blocked|positive_fold_blocked|could_join|subtype_via_membership|membership_world_range|'
                 r'jl_has_open_set_in|jl_is_all_type|intersect_var|obvious_subtype @ subtype|set_bounded_pattern|'
                 r'membership_bounded_patterns|value_entries_range|jl_type_has_kind')
builds = [(a.split('=', 1)[0], a.split('=', 1)[1].split(',')) for a in sys.argv[1:]]
for phase in ('load', 'work'):
    data = {}
    for b, pres in builds:
        d = collections.defaultdict(lambda: [0.0, 0.0]); tot = 0
        for p in pres:
            L = open(f'{p}-{phase}.tsv').read().splitlines(); tot += int(L[0].split('\t')[3])
            for l in L[1:]:
                c, s, n = l.split('\t', 2)
                if PAT.search(n):
                    d[n][0] += int(c) / len(pres); d[n][1] += int(s) / len(pres)
        data[b] = (d, tot / len(pres))
    print('==', phase, '| mean samples per profile:', ', '.join(f'{b} {round(v[1])}' for b, v in data.items()))
    names = set().union(*[set(v[0]) for v in data.values()])
    for n in sorted(names, key=lambda n: -max(data[b][0].get(n, [0, 0])[0] for b, _ in builds)):
        print('%-48s' % n[:48], '  '.join('%s %6.1f/%5.1f' % (b, *data[b][0].get(n, [0, 0])) for b, _ in builds))
