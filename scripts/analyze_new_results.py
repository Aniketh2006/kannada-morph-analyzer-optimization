#!/usr/bin/env python3
"""Statistics for the three newer experiments (standard library only).

Usage (repository root):
    python3 scripts/analyze_new_results.py raw_results/linux_ubuntu_performance linux results_new_linux.csv

Reads  result_analyzer_endtoend_<tag>.csv, result_lookup_isolated_<tag>.csv,
       result_parallel_analyzer_<tag>.csv   from the given folder.

Rules (fixed before the data were seen)
  * end-to-end : run 1 of each condition is the pre-declared warm-up and is excluded; all others are kept
  * lookup, parallel : every recorded run is kept
  * CI of a mean = Student-t 95% interval; ratio CIs = percentile bootstrap, 10,000 resamples, seed fixed
  * end-to-end ratios resample whole runs (original and optimized from the same run stay paired)
"""
import csv
import os
import random
import statistics as st
import sys

folder = sys.argv[1]
tag = sys.argv[2]
out_path = sys.argv[3] if len(sys.argv) > 3 else f"results_new_{tag}.csv"
random.seed(20261024)

# Student-t 97.5% quantiles, df = 1..30 (df > 30 -> 1.96 is a close approximation)
T = [12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228, 2.201, 2.179, 2.160, 2.145,
     2.131, 2.120, 2.110, 2.101, 2.093, 2.086, 2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048,
     2.045, 2.042]


def t975(n):
    return T[n - 2] if n - 1 <= 30 else 1.96


def desc(x):
    n = len(x)
    m = st.mean(x)
    sd = st.stdev(x) if n > 1 else 0.0
    h = t975(n) * sd / n ** 0.5 if n > 1 else 0.0
    return dict(n=n, mean=m, median=st.median(x), sd=sd, cv=100 * sd / m if m else 0.0,
                lo=m - h, hi=m + h)


def boot_paired(a, b, reps=10000):
    """CI of mean(a)/mean(b) resampling run indices jointly."""
    idx = range(len(a))
    r = []
    for _ in range(reps):
        s = [random.choice(idx) for _ in idx]
        r.append(st.mean(a[i] for i in s) / st.mean(b[i] for i in s))
    r.sort()
    return r[int(0.025 * reps)], r[int(0.975 * reps)]


def boot_indep(a, b, reps=10000):
    r = []
    for _ in range(reps):
        r.append(st.mean(random.choices(a, k=len(a))) / st.mean(random.choices(b, k=len(b))))
    r.sort()
    return r[int(0.025 * reps)], r[int(0.975 * reps)]


def rd(name):
    p = os.path.join(folder, f"{name}_{tag}.csv")
    with open(p, newline="") as f:
        return list(csv.DictReader(f))


rows = []

# ---------------------------------------------------------------- end-to-end
e2e = rd("result_analyzer_endtoend")
print("== END-TO-END (original vs optimized analyzer, 100 words, warm-up excluded) ==")
for cond in ("quiet", "shipped"):
    r = [x for x in e2e if x["condition"] == cond and x["warmup"] == "0"]
    o = [float(x["original_ms"]) for x in r]
    p = [float(x["optimized_ms"]) for x in r]
    d_o, d_p = desc(o), desc(p)
    lo, hi = boot_paired(o, p)
    sp = st.mean(o) / st.mean(p)
    # order effect: ratio when original ran first vs optimized ran first
    of = [(float(x["original_ms"]), float(x["optimized_ms"])) for x in r if x["first"] == "original"]
    pf = [(float(x["original_ms"]), float(x["optimized_ms"])) for x in r if x["first"] == "optimized"]
    sp_of = st.mean(a for a, _ in of) / st.mean(b for _, b in of)
    sp_pf = st.mean(a for a, _ in pf) / st.mean(b for _, b in pf)
    allr = [x for x in e2e if x["condition"] == cond]
    sp_all = st.mean(float(x["original_ms"]) for x in allr) / st.mean(float(x["optimized_ms"]) for x in allr)
    print(f"{cond:8} n={len(o)}  original {d_o['mean']:.1f} ms [{d_o['lo']:.1f}-{d_o['hi']:.1f}] (median {d_o['median']:.1f}, CV {d_o['cv']:.1f}%)"
          f" | optimized {d_p['mean']:.1f} [{d_p['lo']:.1f}-{d_p['hi']:.1f}] (median {d_p['median']:.1f}, CV {d_p['cv']:.1f}%)")
    print(f"         speed-up {sp:.2f}x (95% CI {lo:.2f}-{hi:.2f}); median ratio {d_o['median'] / d_p['median']:.2f}x; "
          f"original-first {sp_of:.2f}x (n={len(of)}), optimized-first {sp_pf:.2f}x (n={len(pf)}); incl. warm-up {sp_all:.2f}x")
    for prog, d in (("original", d_o), ("optimized", d_p)):
        rows.append(dict(experiment="endtoend", condition=cond, method=prog, size="100 words", n=d["n"],
                         mean_ms=round(d["mean"], 3), median_ms=round(d["median"], 3), sd_ms=round(d["sd"], 3),
                         cv_pct=round(d["cv"], 1), ci95_low=round(d["lo"], 3), ci95_high=round(d["hi"], 3),
                         ratio=("1" if prog == "original" else f"{sp:.3f}"),
                         ratio_ci95=("" if prog == "original" else f"{lo:.2f}-{hi:.2f}"),
                         note=("baseline" if prog == "original" else f"order-effect: orig-first {sp_of:.2f}, opt-first {sp_pf:.2f}")))

# ---------------------------------------------------------------- isolated lookup
lk = rd("result_lookup_isolated")
print("\n== ISOLATED LOOKUP (loading excluded; ratio = binary / hash time) ==")
for n in sorted({int(x["queries"]) for x in lk}):
    r = [x for x in lk if int(x["queries"]) == n]
    h = [float(x["hash_ms"]) for x in r]
    b = [float(x["binary_ms"]) for x in r]
    assert all(x["hits_hash"] == x["hits_binary"] for x in r), "hit counts differ"
    dh, db = desc(h), desc(b)
    lo, hi = boot_paired(b, h)
    ratio = st.mean(b) / st.mean(h)
    ns_h, ns_b = 1e6 * dh["mean"] / n, 1e6 * db["mean"] / n
    h2, b2 = h[1:], b[1:]
    ratio_wo1 = st.mean(b2) / st.mean(h2)
    print(f"{n:>8} q  runs={len(r):2}  hash {dh['mean']:.4f} ms ({ns_h:.0f} ns/q) | binary {db['mean']:.4f} ms ({ns_b:.0f} ns/q) | "
          f"binary/hash {ratio:.1f}x (CI {lo:.1f}-{hi:.1f}); without run 1: {ratio_wo1:.1f}x")
    for m, d, ns in (("hash", dh, ns_h), ("binary", db, ns_b)):
        rows.append(dict(experiment="lookup_isolated", condition="", method=m, size=f"{n} queries", n=d["n"],
                         mean_ms=round(d["mean"], 4), median_ms=round(d["median"], 4), sd_ms=round(d["sd"], 4),
                         cv_pct=round(d["cv"], 1), ci95_low=round(d["lo"], 4), ci95_high=round(d["hi"], 4),
                         ratio=("1" if m == "hash" else f"{ratio:.2f}"),
                         ratio_ci95=("" if m == "hash" else f"{lo:.1f}-{hi:.1f}"),
                         note=f"{ns:.0f} ns/query"))

# ---------------------------------------------------------------- parallel analyzer
pa = rd("result_parallel_analyzer")
print("\n== PARALLEL ANALYZER (wall clock, whole batch; speed-up vs 1 process) ==")
for n in sorted({int(x["words"]) for x in pa}):
    base = [float(x["wall_ms"]) for x in pa if int(x["words"]) == n and int(x["workers"]) == 1]
    for k in sorted({int(x["workers"]) for x in pa if int(x["words"]) == n}):
        v = [float(x["wall_ms"]) for x in pa if int(x["words"]) == n and int(x["workers"]) == k]
        d = desc(v)
        if k == 1:
            sp, ci, eff = 1.0, "", 1.0
        else:
            sp = st.mean(base) / st.mean(v)
            lo, hi = boot_indep(base, v)
            ci, eff = f"{lo:.2f}-{hi:.2f}", sp / k
        print(f"{n:>6} words  {k} proc  runs={d['n']:2}  {d['mean']:9.1f} ms [{d['lo']:.1f}-{d['hi']:.1f}]  CV {d['cv']:.1f}%  "
              f"speed-up {sp:.2f}x {('(' + ci + ')') if ci else ''}  efficiency {100 * eff:.0f}%")
        rows.append(dict(experiment="parallel_analyzer", condition="", method=f"{k} process(es)", size=f"{n} words",
                         n=d["n"], mean_ms=round(d["mean"], 3), median_ms=round(d["median"], 3), sd_ms=round(d["sd"], 3),
                         cv_pct=round(d["cv"], 1), ci95_low=round(d["lo"], 3), ci95_high=round(d["hi"], 3),
                         ratio=f"{sp:.3f}", ratio_ci95=ci, note=f"efficiency {100 * eff:.0f}%"))

with open(out_path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
print(f"\nsaved {out_path}")
