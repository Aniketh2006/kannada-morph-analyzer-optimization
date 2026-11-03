# Benchmark Report — Paradigm-Based Kannada Morphological Analyzer (DIDL-DL MT)

Same-hardware Ubuntu vs Windows evaluation of the three optimizations requested by the project guide:
(i) removing non-essential regular expressions, (ii) binary search on a sorted dictionary,
(iii) multicore processing. All statistics below are recomputed from the raw per-run CSV files in
`raw_results/` by `scripts/analyze_results.py`; nothing is typed by hand (`scripts/build_report.py`).

## 1. Verification summary

| Guide's requirement | Present? | Evidence | Scope of what was measured |
|---|---|---|---|
| (i) Remove non-essential regex | **Yes** | `result_person1_regex.csv`, 5 runs/OS | **Dictionary loader only.** Analyzer-level timing is not in the data. |
| (ii) Binary search on sorted dictionary | **Yes** | `result_person2_bsearch.csv` (5 runs), `result_mce.csv` (10 runs) | Load + 100 lookups. Gain comes from the pre-processed sorted file, not from the search step (see §6). |
| (iii) Multicore (MCE, process-based) | **Yes** | `result_mce.csv`, 10 runs/OS | MCE over **dictionary lookups only**; the analyzer's analysis loop is not parallelised. |

Correctness evidence: original and optimized analyzers give **byte-identical, non-empty output** on the 100 test words
(Ubuntu: True; Windows: True; Ubuntu vs Windows after CR normalisation: True).
The 3,361 distinct FSA suffix strings contain **no regex metacharacters**, so replacing the interpolated pattern
`$word =~ /$suffix$/` by `substr` comparison is semantically equivalent for this resource.

## 2. Environment (same physical machine, dual boot)

| Item | Value | Source |
|---|---|---|
| Device | HP ProBook 450 15.6-inch G9 | Windows doc |
| CPU | 12th Gen Intel Core i5-1235U (hybrid; 12 threads per vendor spec) | Windows doc |
| RAM / storage | 8 GB (7.64 GB usable), 3200 MHz / WD Green SN350 1 TB SSD | Windows doc |
| Windows | Windows 10 Pro 22H2, build 19045.6466; Balanced then High-performance plan | Windows doc |
| Linux | Ubuntu 24.04, system Perl 5.38.2, `libmce-perl`; governor `performance` | Linux doc |
| Inputs | identical `dict_all.txt`, `dfsa_270526.txt`, `morph_kan*.pl`, test words (SHA-256 equal after CR strip) | verified |

**Recorded for the later sessions (E, L, PAR):** Ubuntu 24.04.4, kernel 7.0.0-38-generic, Perl 5.38.2, MCE 1.889, AC connected (23 Oct 2026);
Windows 10 build 19045.6466, Perl 5.42.2, MCE 1.904, AC connected, Defender real-time protection on (1 Nov 2026).
**Not recorded:** the Perl/MCE versions of the earlier P1/P2/B1 sessions, thermal state. Note the Perl versions of the two later sessions differ.

## 3. Data hygiene

* `old_speed_results.csv`, `speed_results.csv` in the zips are **stale** (an earlier, different script); excluded.
* The first Linux session ran with governor `powersave` and its P2/B1 runs crashed on a case-sensitive file name;
  the Linux write-up documents this and uses only the later, valid session. The discarded run was not archived.
* The repository keeps **one** test-word file name, `random_words_100.txt` (the zip's `Random_words_100.txt` collides on case-insensitive file systems).
* `alloMorphMappingFile.txt` is **0 bytes**, also in the guide's original zip: no allomorph rules were applied in any experiment.

## 4. What each experiment actually compares

| ID | Baseline | Candidate | Data held in memory |
|---|---|---|---|
| P1 | original loader (5 regex ops/line) | regex-free loader (`tr`, `index`, `split` limit) | full values + gender map |
| P2 | regex-free hash loader | pre-built sorted file + binary search | full values (verified equal) |
| B1 | regex-free hash of root words | Storable cache; sorted file + binary search; MCE (4 workers) | **root-word existence only** |

Baselines differ per experiment, so speed-ups are **not comparable or multiplicable across experiments**.

## 5. Results (all runs included; mean ± 95% t-interval; speed-up CI by bootstrap)

### 5.1 Primary like-for-like pair: Ubuntu (performance governor) and Windows (High performance)

**Ubuntu 24.04**

| Experiment | Method | n | Mean ms (95% CI) | Median | SD | CV % | Speed-up (95% CI) |
|---|---|--:|---|--:|--:|--:|---|
| P1  loader: original-regex vs regex-free | Original_Regex | 5 | 140.5 (123.3–157.6) | 133.5 | 13.8 | 9.8 | baseline |
| P1  loader: original-regex vs regex-free | Optimized_NoRegex | 5 | 122.5 (119.7–125.3) | 123.0 | 2.2 | 1.8 | **1.15×** (1.08-1.25) |
| P2  regex-free hash vs sorted file + binary search, full values | Normal_Hash | 5 | 124.1 (119.7–128.5) | 123.0 | 3.6 | 2.9 | baseline |
| P2  regex-free hash vs sorted file + binary search, full values | Binary_Search | 5 | 49.2 (47.7–50.7) | 49.4 | 1.2 | 2.4 | **2.52×** (2.45-2.60) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Normal Hash | 10 | 63.0 (62.3–63.7) | 62.7 | 1.0 | 1.5 | baseline |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Storable Binary Cache | 10 | 15.6 (14.6–16.7) | 16.1 | 1.4 | 9.2 | **4.03×** (3.83-4.27) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Sorted + Binary Search | 10 | 11.2 (10.7–11.7) | 11.2 | 0.7 | 6.2 | **5.60×** (5.39-5.81) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | MCE (4 workers) | 10 | 145.8 (143.6–148.0) | 145.6 | 3.0 | 2.1 | **0.43×** (0.43-0.44) |

**Windows 10, High performance**

| Experiment | Method | n | Mean ms (95% CI) | Median | SD | CV % | Speed-up (95% CI) |
|---|---|--:|---|--:|--:|--:|---|
| P1  loader: original-regex vs regex-free | Original_Regex | 5 | 529.1 (325.7–732.5) | 427.0 | 163.8 | 31.0 | baseline |
| P1  loader: original-regex vs regex-free | Optimized_NoRegex | 5 | 418.3 (229.1–607.5) | 350.2 | 152.4 | 36.4 | **1.26×** (0.86-1.81) |
| P2  regex-free hash vs sorted file + binary search, full values | Normal_Hash | 5 | 382.6 (358.5–406.6) | 376.1 | 19.4 | 5.1 | baseline |
| P2  regex-free hash vs sorted file + binary search, full values | Binary_Search | 5 | 103.1 (91.4–114.9) | 102.0 | 9.5 | 9.2 | **3.71×** (3.40-4.00) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Normal Hash | 10 | 256.0 (246.2–265.8) | 250.9 | 13.7 | 5.4 | baseline |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Storable Binary Cache | 10 | 25.4 (23.3–27.6) | 24.6 | 3.0 | 11.8 | **10.06×** (9.30-10.79) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Sorted + Binary Search | 10 | 30.5 (27.6–33.4) | 29.1 | 4.0 | 13.3 | **8.40×** (7.68-9.05) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | MCE (4 workers) | 10 | 552.5 (524.3–580.8) | 544.1 | 39.4 | 7.1 | **0.46×** (0.44-0.49) |

### 5.2 Supplementary: Windows Balanced plan

| Experiment | Method | n | Mean ms (95% CI) | Median | SD | CV % | Speed-up (95% CI) |
|---|---|--:|---|--:|--:|--:|---|
| P1  loader: original-regex vs regex-free | Original_Regex | 5 | 864.6 (584.0–1145.1) | 813.2 | 226.0 | 26.1 | baseline |
| P1  loader: original-regex vs regex-free | Optimized_NoRegex | 5 | 804.3 (591.3–1017.3) | 794.0 | 171.6 | 21.3 | **1.07×** (0.82-1.40) |
| P2  regex-free hash vs sorted file + binary search, full values | Normal_Hash | 5 | 935.7 (882.0–989.4) | 943.1 | 43.3 | 4.6 | baseline |
| P2  regex-free hash vs sorted file + binary search, full values | Binary_Search | 5 | 209.6 (171.7–247.5) | 198.6 | 30.5 | 14.6 | **4.46×** (3.94-4.93) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Normal Hash | 10 | 498.5 (489.3–507.7) | 495.7 | 12.8 | 2.6 | baseline |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Storable Binary Cache | 10 | 35.1 (31.7–38.5) | 33.0 | 4.7 | 13.5 | **14.21×** (13.04-15.21) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | Sorted + Binary Search | 10 | 51.5 (43.1–60.0) | 47.6 | 11.8 | 22.9 | **9.67×** (8.46-11.04) |
| B1  root-set: hash vs Storable vs sorted+binary vs MCE-4 | MCE (4 workers) | 10 | 601.6 (499.6–703.6) | 539.6 | 142.6 | 23.7 | **0.83×** (0.72-0.93) |

### 5.3 Absolute-time ratio, Windows (High performance) / Ubuntu

| Experiment | Method | Windows High-perf (ms) | Ubuntu performance (ms) | Windows / Ubuntu |
|---|---|--:|--:|--:|
| P1 | Original_Regex | 529.1 | 140.5 | 3.8× |
| P1 | Optimized_NoRegex | 418.3 | 122.5 | 3.4× |
| P2 | Normal_Hash | 382.6 | 124.1 | 3.1× |
| P2 | Binary_Search | 103.1 | 49.2 | 2.1× |
| B1 | Normal Hash | 256.0 | 63.0 | 4.1× |
| B1 | Storable Binary Cache | 25.4 | 15.6 | 1.6× |
| B1 | Sorted + Binary Search | 30.5 | 11.2 | 2.7× |
| B1 | MCE (4 workers) | 552.5 | 145.8 | 3.8× |

## 6. Interpretation

**Supported by the data**
1. Pre-processed dictionary workflows cut load-and-lookup time on both systems; every confidence interval excludes 1.0
   (Storable 4.0× Ubuntu / 10.1× Windows; sorted file + binary search 5.6× / 8.4× against the root-set baseline).
2. Four-worker MCE is **slower** than serial lookup on both systems (0.43× / 0.46×): start-up cost exceeds 100 lookups.
3. Regex removal in the **loader** gives 1.15× on Ubuntu (CI 1.08–1.25). On Windows the interval includes 1.0
   (High-performance 0.86–1.81; Balanced 0.82–1.40) — **no effect can be claimed there** (CV 21–36 %, n = 5, slow first run).

**Not supported / not tested**
* Which of the three changes in `morph_kan.pl` (suffix test `=~ /$suffix8$/` → `substr`, 21 commented-out debug prints,
  rewritten loader) causes the end-to-end gain of §9. The loader is worth ≈18 ms (P1); the split between the other two needs an ablation.
* That binary search beats hash lookup: it does not (§9: 20–36× slower in Perl). The P2/B1 gains come from avoiding per-line parsing and hash construction.
* Multicore benefit for the analyzer: shown in §9 (process-level batch partitioning, order preserved, no shared globals); dictionary-lookup MCE alone is slower than serial.

## 7. Flaws found and how each is closed

| # | Flaw | Impact | Solution | Status |
|---|---|---|---|---|
| 1 | No end-to-end timing of the real analyzer | headline claim missing; regex removal measured in the wrong place | `time_analyzers.pl` (alternating order, pre-declared warm-up, quiet/shipped conditions) | closed — see §9 |
| 2 | MCE test never runs the analyzer | multicore claim unsupported | `parallel_analyzer_benchmark.pl` | closed — see §9 |
| 3 | Binary-search gain confounded with pre-processing | wrong causal claim | `lookup_isolated_benchmark.pl`; reword in paper | closed — see §9 |
| 4 | Three experiments, three different baselines, data models differ | speed-ups not comparable | state in text (done); optionally re-base all on one loader | wording done |
| 5 | n = 5 for P1/P2; CV up to 36 % on Windows | regex result inconclusive | ≥ 30 runs, pre-declared warm-up, alternating order | rerun advised |
| 6 | P1 always runs original first, then optimized | order/warm-cache bias toward the candidate | alternate order (as in `time_analyzers.pl`) | rerun advised |
| 7 | Windows Perl version, MCE versions, Linux CPU/kernel, AC state not recorded | not reproducible | env-snapshot scripts | closed — see §9 |
| 8 | Linux write-up compares Ubuntu-performance with Windows-**Balanced** and quotes "4–8×" and "2–8×" | apples-to-oranges | use Windows High-performance (§5.3) | fixed here |
| 9 | Warm file cache: each run re-reads the same files from the OS cache | disk speed not measured | state "warm cache" in the paper | wording done |
| 10 | Discarded `powersave` session not archived | selective-reporting risk | state it in the paper; archive next time | wording done |
| 11 | `alloMorphMappingFile.txt` empty | allomorph stage not exercised | state it; confirm with the guide | ask guide |

## 8. Reproduce

See `README.md`. Statistics: `python3 scripts/analyze_results.py raw_results results_summary.csv`
and `python3 scripts/analyze_new_results.py raw_results/<system> <tag> results_new_<tag>.csv`.

## 9. Newer experiments: end-to-end (E), isolated look-up (L), parallel analyzer (PAR)

Run in later sessions with `scripts/time_analyzers.pl 31`, `scripts/lookup_isolated_benchmark.pl`, `PA_RUNS=10 scripts/parallel_analyzer_benchmark.pl`.
E: warm-up run excluded, whole runs bootstrapped. L: all runs. PAR: speed-up over one process. Statistics: `scripts/analyze_new_results.py`.

**Ubuntu 24.04**

| Experiment | Size / condition | Method | n | Mean ms (95% CI) | CV % | Ratio (95% CI) | Note |
|---|---|---|--:|---|--:|---|---|
| endtoend | 100 words quiet | original | 30 | 6326.29 (6253.86–6398.72) | 3.1 | baseline | baseline |
| endtoend | 100 words quiet | optimized | 30 | 511.90 (500.44–523.37) | 6.0 | 12.36× (12.17-12.54) | order-effect: orig-first 12.40, opt-first 12.32 |
| endtoend | 100 words shipped | original | 30 | 6237.67 (6221.22–6254.11) | 0.7 | baseline | baseline |
| endtoend | 100 words shipped | optimized | 30 | 493.94 (491.02–496.86) | 1.6 | 12.63× (12.55-12.70) | order-effect: orig-first 12.65, opt-first 12.60 |
| lookup_isolated | 100 queries  | hash | 10 | 0.01 (0.00–0.01) | 102.6 | baseline | 57 ns/query |
| lookup_isolated | 100 queries  | binary | 10 | 0.21 (0.18–0.24) | 21.4 | 37.07× (25.2-58.2) | 2113 ns/query |
| lookup_isolated | 10000 queries  | hash | 10 | 0.93 (0.61–1.25) | 48.1 | baseline | 93 ns/query |
| lookup_isolated | 10000 queries  | binary | 10 | 21.26 (20.49–22.04) | 5.1 | 22.87× (17.9-29.6) | 2126 ns/query |
| lookup_isolated | 1000000 queries  | hash | 5 | 75.45 (63.34–87.55) | 12.9 | baseline | 75 ns/query |
| lookup_isolated | 1000000 queries  | binary | 5 | 2154.15 (2122.94–2185.36) | 1.2 | 28.55× (26.2-31.4) | 2154 ns/query |
| parallel_analyzer | 100 words  | 1 process(es) | 10 | 524.68 (510.86–538.51) | 3.7 | baseline | efficiency 100% |
| parallel_analyzer | 100 words  | 2 process(es) | 10 | 396.70 (393.34–400.05) | 1.2 | 1.32× (1.29-1.35) | efficiency 66% |
| parallel_analyzer | 100 words  | 4 process(es) | 10 | 428.30 (418.13–438.48) | 3.3 | 1.23× (1.19-1.26) | efficiency 31% |
| parallel_analyzer | 100 words  | 8 process(es) | 10 | 493.64 (486.94–500.35) | 1.9 | 1.06× (1.04-1.09) | efficiency 13% |
| parallel_analyzer | 1000 words  | 1 process(es) | 10 | 3398.19 (3348.55–3447.83) | 2.0 | baseline | efficiency 100% |
| parallel_analyzer | 1000 words  | 2 process(es) | 10 | 1904.06 (1888.80–1919.32) | 1.1 | 1.78× (1.76-1.81) | efficiency 89% |
| parallel_analyzer | 1000 words  | 4 process(es) | 10 | 1677.33 (1614.48–1740.19) | 5.2 | 2.03× (1.96-2.10) | efficiency 51% |
| parallel_analyzer | 1000 words  | 8 process(es) | 10 | 1827.84 (1808.20–1847.48) | 1.5 | 1.86× (1.83-1.89) | efficiency 23% |
| parallel_analyzer | 5000 words  | 1 process(es) | 10 | 16314.65 (16148.34–16480.96) | 1.4 | baseline | efficiency 100% |
| parallel_analyzer | 5000 words  | 2 process(es) | 10 | 9075.76 (8903.60–9247.91) | 2.7 | 1.80× (1.77-1.83) | efficiency 90% |
| parallel_analyzer | 5000 words  | 4 process(es) | 10 | 7946.27 (7196.26–8696.28) | 13.2 | 2.05× (1.89-2.21) | efficiency 51% |
| parallel_analyzer | 5000 words  | 8 process(es) | 10 | 7351.43 (6958.48–7744.39) | 7.5 | 2.22× (2.11-2.31) | efficiency 28% |

**Windows 10 (High performance)**

| Experiment | Size / condition | Method | n | Mean ms (95% CI) | CV % | Ratio (95% CI) | Note |
|---|---|---|--:|---|--:|---|---|
| endtoend | 100 words quiet | original | 30 | 18722.61 (17907.05–19538.17) | 11.7 | baseline | baseline |
| endtoend | 100 words quiet | optimized | 30 | 1022.71 (990.65–1054.77) | 8.4 | 18.31× (17.59-19.01) | order-effect: orig-first 18.66, opt-first 17.95 |
| endtoend | 100 words shipped | original | 30 | 19235.49 (18369.79–20101.18) | 12.1 | baseline | baseline |
| endtoend | 100 words shipped | optimized | 30 | 1142.81 (1060.65–1224.96) | 19.3 | 16.83× (15.68-17.96) | order-effect: orig-first 16.35, opt-first 17.33 |
| lookup_isolated | 100 queries  | hash | 10 | 0.01 (0.00–0.01) | 109.1 | baseline | 78 ns/query |
| lookup_isolated | 100 queries  | binary | 10 | 0.32 (0.29–0.36) | 15.3 | 41.40× (26.8-71.2) | 3229 ns/query |
| lookup_isolated | 10000 queries  | hash | 10 | 1.63 (1.08–2.18) | 47.1 | baseline | 163 ns/query |
| lookup_isolated | 10000 queries  | binary | 10 | 32.71 (31.97–33.44) | 3.1 | 20.05× (15.8-27.5) | 3271 ns/query |
| lookup_isolated | 1000000 queries  | hash | 5 | 110.28 (77.93–142.64) | 23.6 | baseline | 110 ns/query |
| lookup_isolated | 1000000 queries  | binary | 5 | 3937.53 (3100.59–4774.47) | 17.1 | 35.70× (32.9-41.2) | 3938 ns/query |
| parallel_analyzer | 100 words  | 1 process(es) | 10 | 897.07 (888.21–905.93) | 1.4 | baseline | efficiency 100% |
| parallel_analyzer | 100 words  | 2 process(es) | 10 | 808.65 (801.43–815.86) | 1.2 | 1.11× (1.10-1.12) | efficiency 55% |
| parallel_analyzer | 100 words  | 4 process(es) | 10 | 1217.24 (1157.65–1276.84) | 6.8 | 0.74× (0.71-0.77) | efficiency 18% |
| parallel_analyzer | 100 words  | 8 process(es) | 10 | 1677.78 (1623.34–1732.22) | 4.5 | 0.54× (0.52-0.55) | efficiency 7% |
| parallel_analyzer | 1000 words  | 1 process(es) | 10 | 5067.78 (4623.42–5512.14) | 12.3 | baseline | efficiency 100% |
| parallel_analyzer | 1000 words  | 2 process(es) | 10 | 3492.57 (3425.65–3559.47) | 2.7 | 1.45× (1.37-1.57) | efficiency 73% |
| parallel_analyzer | 1000 words  | 4 process(es) | 10 | 3274.44 (3225.96–3322.92) | 2.1 | 1.55× (1.47-1.68) | efficiency 39% |
| parallel_analyzer | 1000 words  | 8 process(es) | 10 | 3281.14 (3217.76–3344.51) | 2.7 | 1.54× (1.46-1.68) | efficiency 19% |
| parallel_analyzer | 5000 words  | 1 process(es) | 10 | 24705.94 (22045.81–27366.07) | 15.1 | baseline | efficiency 100% |
| parallel_analyzer | 5000 words  | 2 process(es) | 10 | 13115.81 (12783.39–13448.24) | 3.5 | 1.88× (1.72-2.06) | efficiency 94% |
| parallel_analyzer | 5000 words  | 4 process(es) | 10 | 10805.37 (10684.09–10926.65) | 1.6 | 2.29× (2.10-2.50) | efficiency 57% |
| parallel_analyzer | 5000 words  | 8 process(es) | 10 | 8808.63 (8691.03–8926.23) | 1.9 | 2.81× (2.57-3.07) | efficiency 35% |


Reading: (E) the optimized analyzer is 12.4× (Ubuntu) / 18.3× (Windows) faster for 100 words with identical output — the gain of three bundled changes;
(L) binary search is 20–36× slower than a hash look-up once loading is excluded, so P2/B1 gains come from pre-processing;
(PAR) whole-analyzer parallelism gives up to 2.2× (Ubuntu) / 2.8× (Windows) on 5,000 words and loses on 100 words with ≥ 4 processes on Windows.
