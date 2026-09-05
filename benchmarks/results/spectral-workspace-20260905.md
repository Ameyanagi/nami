# Reusable spectral analysis — 2026-09-05

Command: `pixi run --locked bench-spectral` (Mojo 1.0.0 `ed45d567`,
`mojo build -I src -O3`; no debug build). Source:
[`bench_spectral_workspace.mojo`](../bench_spectral_workspace.mojo).

Host: Apple M4, 10 CPUs, ARM64, macOS 26.5.1 (25F80). Measured around
2026-09-05 09:11 UTC. The host was shared with concurrent compilation;
load averages were 39.25 / 26.06 / 16.06. `pmset -g therm` reported no recorded
thermal or performance warning. This is a reproducible local comparison, not a
latency guarantee: contention particularly affects the p95 values.

Each input is the deterministic sum of unit-amplitude bin 7 and quarter-amplitude
bin 11 sinusoids. Welch receives four repetitions and uses default half overlap,
giving seven complete frames. Each case gets three warmups and 31 samples of 32
operations, using `perf_counter_ns`. The table reports integer nanoseconds per
operation (batch elapsed divided by 32). Construction includes destruction.
The checksum is consumed outside timing; all results are retained with `keep`.

| FFT size | Case | p50 ns | p95 ns |
| --- | --- | ---: | ---: |
| 64 | FFT plan construction | 2,781 | 4,000 |
| 64 | Workspace construction | 3,625 | 7,093 |
| 64 | Before: allocating periodogram | 7,843 | 15,937 |
| 64 | After: reused periodogram | 2,531 | 6,718 |
| 64 | Before: allocating Welch (7 frames) | 24,843 | 30,968 |
| 64 | After: reused Welch (7 frames) | 19,437 | 31,093 |
| 4096 | FFT plan construction | 98,031 | 155,781 |
| 4096 | Workspace construction | 164,812 | 340,968 |
| 4096 | Before: allocating periodogram | 382,968 | 618,937 |
| 4096 | After: reused periodogram | 177,531 | 892,781 |
| 4096 | Before: allocating Welch (7 frames) | 1,749,500 | 3,715,250 |
| 4096 | After: reused Welch (7 frames) | 1,503,468 | 2,393,125 |

“Before” is the existing allocating API; “after” uses the new workspace API in
the same revision with identical overflow-resistant numerical kernels. This
isolates the reuse benefit from the separate numerical-correctness changes.
The observed median periodogram speedups are 3.10× and 2.16×; Welch's median
speedups are 1.28× and 1.16×. The noisy p95 samples do not support a universal
p95 improvement claim. Welch gains less because its one-shot implementation
already reused a plan within a single multi-frame operation.

Successful workspace calls do not allocate or resize analysis storage: the plan,
Hann window, real frame, complex spectrum, and integer exponent list are created
once, and the caller allocates output once. This is verified by the call graph
and fixed-size buffer implementation; this benchmark does not instrument the
allocator. Frequency output is excluded from the reused hot loop since equal
FFT size and sample rate permit coordinates to be computed once.

Correctness is separately covered by SciPy fixtures, an independent direct DFT
for all overlaps at length 8, repeated frames at sizes 2/4/8/16, cross-estimator
reuse and recovery after errors, plus maximum/subnormal arithmetic regressions.
