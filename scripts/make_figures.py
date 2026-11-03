#!/usr/bin/env python3
"""Regenerate the two figures of the paper from the result CSV files.

Usage (repository root):   python3 scripts/make_figures.py
Needs: matplotlib.  Reads results_summary.csv, results_new_linux.csv, results_new_windows.csv
Writes: figures/speedups.pdf|png and figures/parallel_scaling.pdf|png (and copies the PDFs to paper/).
The figures contain no data of their own: every bar and point is a value from those CSV files.
"""
import csv
import shutil

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams.update({"font.family": "serif", "font.size": 8, "pdf.fonttype": 42})

# ---------------------------------------------------------------- Figure: speed-ups of P1, P2, B1
rows = list(csv.DictReader(open("results_summary.csv")))


def get(env, exp, method):
    return next(r for r in rows if r["environment"] == env and r["experiment"] == exp and r["method"] == method)


items = [("Regex-free\nloader", "person1_regex", "Optimized_NoRegex"),
         ("Hash→sorted\nfile + bin. search\n(full values)", "person2_bsearch", "Binary_Search"),
         ("Storable\ncache\n(root set)", "mce", "Storable Binary Cache"),
         ("Sorted file +\nbin. search\n(root set)", "mce", "Sorted + Binary Search"),
         ("MCE,\n4 workers", "mce", "MCE (4 workers)")]
envs = [("linux_ubuntu_performance", "Ubuntu 24.04 (performance governor)", "#4C72B0"),
        ("windows_high_performance", "Windows 10 (High performance)", "#DD8452")]
fig, ax = plt.subplots(figsize=(3.45, 2.7))
w = 0.38
for j, (env, lab, col) in enumerate(envs):
    xs = [i + (j - 0.5) * w for i in range(len(items))]
    ys, lo, hi = [], [], []
    for (_, exp, m) in items:
        r = get(env, exp, m)
        s = float(r["speedup_of_means"])
        a, b = map(float, r["speedup_ci95"].split("-"))
        ys.append(s); lo.append(s - a); hi.append(b - s)
    ax.bar(xs, ys, w, color=col, label=lab, yerr=[lo, hi], capsize=1.5, error_kw={"lw": 0.6})
ax.axhline(1, color="k", lw=0.7, ls="--")
ax.set_yscale("log"); ax.set_ylim(0.3, 25)
ax.set_yticks([0.5, 1, 2, 5, 10, 20]); ax.set_yticklabels(["0.5", "1", "2", "5", "10", "20"])
ax.set_xticks(range(len(items))); ax.set_xticklabels([i[0] for i in items], fontsize=5.5)
ax.set_ylabel("Speed-up vs. its own baseline (×, log)")
ax.legend(fontsize=5.5, loc="upper left", frameon=False)
ax.grid(axis="y", lw=0.3, alpha=0.5)
fig.tight_layout()
fig.savefig("figures/speedups.pdf"); fig.savefig("figures/speedups.png", dpi=200)
plt.close(fig)

# ---------------------------------------------------------------- Figure: parallel analyzer scaling
data = {"Ubuntu": list(csv.DictReader(open("results_new_linux.csv"))),
        "Windows": list(csv.DictReader(open("results_new_windows.csv")))}


def pts(osname, words):
    out = []
    for k in (1, 2, 4, 8):
        r = next(x for x in data[osname] if x["experiment"] == "parallel_analyzer"
                 and x["size"] == f"{words} words" and x["method"] == f"{k} process(es)")
        s = float(r["ratio"])
        lo, hi = (s, s) if not r["ratio_ci95"] else map(float, r["ratio_ci95"].split("-"))
        out.append((k, s, s - lo, hi - s))
    return out


fig, ax = plt.subplots(figsize=(3.45, 2.5))
colors = {100: "#999999", 1000: "#4C72B0", 5000: "#C44E52"}
for words in (100, 1000, 5000):
    for osname, ls, mk in (("Ubuntu", "-", "o"), ("Windows", "--", "s")):
        p = pts(osname, words)
        ax.errorbar([a[0] for a in p], [a[1] for a in p], yerr=[[a[2] for a in p], [a[3] for a in p]],
                    color=colors[words], ls=ls, marker=mk, ms=3, lw=1, capsize=1.5, elinewidth=0.6,
                    label=f"{words} words, {osname}")
ax.plot([1, 8], [1, 8], color="k", ls=":", lw=0.7, label="ideal")
ax.set_xscale("log", base=2); ax.set_yscale("log", base=2)
ax.set_xticks([1, 2, 4, 8]); ax.set_xticklabels(["1", "2", "4", "8"])
ax.set_yticks([0.5, 1, 2, 4, 8]); ax.set_yticklabels(["0.5", "1", "2", "4", "8"])
ax.set_xlabel("analyzer processes"); ax.set_ylabel("speed-up over 1 process")
ax.grid(lw=0.3, alpha=0.5)
ax.legend(fontsize=5, ncol=2, frameon=False, loc="upper left")
fig.tight_layout()
fig.savefig("figures/parallel_scaling.pdf"); fig.savefig("figures/parallel_scaling.png", dpi=200)
plt.close(fig)

for name in ("speedups", "parallel_scaling"):
    shutil.copy(f"figures/{name}.pdf", f"paper/{name}.pdf")
print("figures regenerated from the CSV files and copied to paper/")
