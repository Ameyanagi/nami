# Reusable spectral analysis — 2026-09-05

Command: `pixi run --locked bench-spectral` (Mojo 1.0.0 `ed45d567`,
`mojo build -I src -O3`; no debug build). Source:
[`bench_spectral_workspace.mojo`](../bench_spectral_workspace.mojo).

Host: Apple M4, 10 CPUs, ARM64, macOS 26.5.1 (25F80). Measured around
2026-09-05 10:02–10:03 UTC. The host was shared with concurrent compilation;
load averages were 19.37 / 14.50 / 16.15. `pmset -g therm` reported no recorded
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
| 64 | FFT plan construction | 2,062 | 3,250 |
| 64 | Workspace construction | 3,687 | 5,375 |
| 64 | Before: allocating periodogram | 12,343 | 15,156 |
| 64 | After: reused periodogram | 7,843 | 9,812 |
| 64 | Before: allocating Welch (7 frames) | 63,093 | 70,218 |
| 64 | After: reused Welch (7 frames) | 58,625 | 61,593 |
| 4096 | FFT plan construction | 91,937 | 154,281 |
| 4096 | Workspace construction | 155,687 | 242,406 |
| 4096 | Before: allocating periodogram | 968,906 | 1,273,937 |
| 4096 | After: reused periodogram | 769,250 | 1,019,156 |
| 4096 | Before: allocating Welch (7 frames) | 5,848,312 | 7,843,312 |
| 4096 | After: reused Welch (7 frames) | 5,652,218 | 6,662,468 |

“Before” is the existing allocating API; “after” uses the new workspace API in
the same revision with identical overflow-resistant numerical kernels. This
isolates the reuse benefit from the separate numerical-correctness changes.
The observed median periodogram speedups are 1.57× and 1.26×; Welch's median
speedups are 1.08× and 1.03×. Expanded centering spends additional arithmetic on
cancellation correctness; both compared paths use the same final kernel. The noisy p95 samples do not support a universal
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
