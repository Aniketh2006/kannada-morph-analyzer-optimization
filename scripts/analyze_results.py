#!/usr/bin/env python3
"""Recompute all statistics from the raw per-run CSV files (standard library only).

Usage (from the repository root):
    python3 scripts/analyze_results.py raw_results results_summary.csv

Definitions
  speedup          = baseline mean / candidate mean (values below 1.0 mean slower)
  95% CI of mean   = Student's t interval (t = 2.776 for 5 runs, 2.262 for 10 runs)
  speedup 95% CI   = percentile bootstrap over runs (10,000 resamples, fixed seed)
  Every recorded run is included. No run is discarded.
"""
import csv
import os
import random
import statistics as st
import sys

T975 = {4: 2.776, 9: 2.262}
ROOT = sys.argv[1] if len(sys.argv) > 1 else "raw_results"
OUT = sys.argv[2] if len(sys.argv) > 2 else "results_summary.csv"
random.seed(20261016)

# (file, baseline label, candidate labels)
EXPERIMENTS = [
    ("result_person1_regex.csv", "Original_Regex", ["Optimized_NoRegex"]),
    ("result_person2_bsearch.csv", "Normal_Hash", ["Binary_Search"]),
    ("result_mce.csv", "Normal Hash",
     ["Storable Binary Cache", "Sorted + Binary Search", "MCE (4 workers)"]),
]


def read_runs(path):
    rows = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows[r["Method"]] = [float(r[k]) for k in r if k.startswith("Run")]
    return rows


def boot_ratio(base, cand, n=10000):
    out = []
    for _ in range(n):
        b = st.mean(random.choices(base, k=len(base)))
        c = st.mean(random.choices(cand, k=len(cand)))
        out.append(b / c)
    out.sort()
    return out[int(0.025 * n)], out[int(0.975 * n)]


rows = []
for env in sorted(os.listdir(ROOT)):
    for fname, base_lbl, cands in EXPERIMENTS:
        p = os.path.join(ROOT, env, fname)
        if not os.path.exists(p):
            continue
        data = read_runs(p)
        base = data[base_lbl]
        for method in [base_lbl] + cands:
            x = data[method]
            n = len(x)
            mean, sd = st.mean(x), st.stdev(x)
            ci = T975[n - 1] * sd / n ** 0.5
            row = dict(
                environment=env,
                experiment=fname.replace("result_", "").replace(".csv", ""),
                method=method, n_runs=n,
                mean_ms=round(mean, 3), median_ms=round(st.median(x), 3),
                sd_ms=round(sd, 3), cv_pct=round(100 * sd / mean, 1),
                ci95_low=round(mean - ci, 3), ci95_high=round(mean + ci, 3),
                min_ms=min(x), max_ms=max(x))
            if method == base_lbl:
                row.update(speedup_of_means="1.000", speedup_of_medians="1.000",
                           speedup_ci95="")
            else:
                lo, hi = boot_ratio(base, x)
                row.update(speedup_of_means=f"{st.mean(base) / mean:.3f}",
                           speedup_of_medians=f"{st.median(base) / st.median(x):.3f}",
                           speedup_ci95=f"{lo:.2f}-{hi:.2f}")
            rows.append(row)

with open(OUT, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), lineterminator="\n")
    w.writeheader()
    w.writerows(rows)

print(f"{'environment':26}{'experiment':16}{'method':24}{'mean':>9}{'median':>9}"
      f"{'sd':>8}{'cv%':>6}  speedup(mean)  95% CI")
for r in rows:
    print(f"{r['environment']:26}{r['experiment']:16}{r['method']:24}{r['mean_ms']:>9}"
          f"{r['median_ms']:>9}{r['sd_ms']:>8}{r['cv_pct']:>6}  "
          f"{r['speedup_of_means']:>11}  {r['speedup_ci95']}")
