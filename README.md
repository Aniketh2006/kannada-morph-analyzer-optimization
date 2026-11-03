# Paradigm-Based Kannada Morphological Analyzer — Speed Benchmarks (DIDL-DL MT)

Benchmarks for the three speed-up ideas from the project guide (remove non-essential regex, binary search on a
sorted dictionary, multicore processing), run on **one laptop that dual-boots Ubuntu and Windows**.

* `BENCHMARK_REPORT.md` – the full report (read this first)
* `results_summary.csv` – every statistic, recomputed from the raw CSVs
* `raw_results/` – per-run timings: `linux_ubuntu_performance/`, `windows_high_performance/`, `windows_balanced/`
* `morph_kan.pl` (optimized) and `morph_kan_original.pl` (as received) – the two analyzers
* `dict_all.txt`, `dfsa_270526.txt`, `alloMorphMappingFile.txt` (empty in the received project), `random_words_100.txt`
* `benchmark1.pl`, `morph_kan_optimized_p1.pl`, `morph_kan_optimized_p2.pl` – the three benchmark scripts already run
* `scripts/` – new scripts (below). `scripts/make_figures.py` redraws both paper figures from the CSV files (`figures/`)

## The three newer measurements (already run: Ubuntu 23 Oct 2026, Windows 1 Nov 2026; data in `raw_results/`)

| Script | Question it answers | Approx. time* |
|---|---|---|
| `scripts/time_analyzers.pl` | How much faster is the **whole optimized analyzer**, end to end? | Linux ~15–25 min, Windows ~30–60 min |
| `scripts/lookup_isolated_benchmark.pl` | Is binary search itself faster than a hash lookup (loading excluded)? | 1–3 min |
| `scripts/parallel_analyzer_benchmark.pl` | Does running several analyzer processes in parallel help? | Linux ~10–20 min, Windows ~30+ min |

\*Estimates only, not measured on your laptop. Quick versions are given below.

## Before you start (both systems, same rules)

1. Plug the laptop into **AC power**. Close the browser and other heavy programs. Do not touch the laptop while a script runs.
2. Open a terminal **inside this folder** (the folder that contains `morph_kan.pl`).
3. Use the **same power setting you used for the earlier runs**: Ubuntu = *performance* governor, Windows = *High performance*.
4. Keep the laptop cool and do not run both systems' tests on the same boot.

## Linux (Ubuntu 24.04) — copy and paste, one line at a time

```bash
sudo apt update && sudo apt install -y perl libmce-perl dos2unix
dos2unix *.pl *.txt scripts/*.pl scripts/*.sh
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
bash scripts/env_snapshot_linux.sh before           # writes environment_linux_before.txt
perl scripts/time_analyzers.pl 31 linux             # quick version: perl scripts/time_analyzers.pl 11 linux
perl scripts/lookup_isolated_benchmark.pl linux
perl scripts/parallel_analyzer_benchmark.pl linux   # quick version: PA_SIZES=100,1000 PA_RUNS=3 perl scripts/parallel_analyzer_benchmark.pl linux
bash scripts/env_snapshot_linux.sh after            # writes environment_linux_after.txt
```

## Windows 10 — PowerShell, one line at a time (same settings as the finished Ubuntu run)

```powershell
powercfg /setactive SCHEME_MIN
perl -v
perl -MMCE -e "print qq(MCE OK\n)"
powershell -ExecutionPolicy Bypass -File scripts\env_snapshot_windows.ps1 before
perl scripts\time_analyzers.pl 31 windows
perl scripts\lookup_isolated_benchmark.pl windows
$env:PA_RUNS="10"; perl scripts\parallel_analyzer_benchmark.pl windows
powershell -ExecutionPolicy Bypass -File scripts\env_snapshot_windows.ps1 after
```

`perl -v` must show version 5.36 or newer (the optimized analyzer uses `builtin::trim`). If the MCE line fails, run `cpanm MCE`.
Ubuntu used exactly these run counts (31 / default / 10), so Windows must too, otherwise the two are not comparable.
Expected time on Ubuntu was about 25 minutes; Windows may take longer.

## What each script prints, and what to do with it

* Each script prints a short summary and saves a CSV named `result_..._<linux|windows>.csv`, plus the two `environment_*` text files.
* A script that prints **`OUTPUT DIFFERS`** or **`ORDER/CONTENT MISMATCH`** has found a real problem: stop and report it, do not average around it.
* Move all new CSV and `environment_*.txt` files into `raw_results/<system>/` and send them with the printed summaries.
* Then regenerate: `python3 scripts/analyze_results.py raw_results results_summary.csv && python3 scripts/build_report.py`

## Rules used for every measurement (decided before looking at the data)

* The **first run is a warm-up** and is excluded from summaries; it stays visible in the CSV.
* Baseline and candidate **alternate order** every run.
* Report **mean with 95% interval and median**; never drop runs because they look slow.
* Timings include loading the dictionary from disk, which is already in the OS file cache (a "warm cache" result).

## Publishing to Git

```bash
git init
git add .
git status                       # check: no *.bin, no dict_sorted*, no *.tmp
git commit -m "Benchmarks: same-hardware Ubuntu/Windows evaluation of analyzer speed-ups"
git branch -M main
git remote add origin <your-repository-url>
git push -u origin main
```

Ask the guide before making the repository **public**: the dictionary and analyzer belong to the MeitY-funded DIDL-DL MT project.
