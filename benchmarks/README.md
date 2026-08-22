# Analysis benchmarks and profiling

`bench_analysis.mojo` compiles four deterministic representative workloads:

- direct convolution of 65,536 samples with a 31-tap kernel, with separate
  native-SIMD and scalar-reference cells over the same private core contract;
- Savitzky-Golay smoothing of 65,536 samples with a 31-sample window;
- Welch PSD of 65,536 samples with 256-sample segments;
- dense peak analysis of 8,192 samples with distance, prominence, and width
  selection, using both owning and caller-owned reusable APIs.

Each case performs three warmups and reports p50/p95 over 31 samples plus a
semantic checksum. Build before timing so compilation is excluded:

```text
pixi run mojo build -I src -O3 benchmarks/bench_analysis.mojo -o .pixi/bench_analysis
./.pixi/bench_analysis
```

The machine-readable header records the schema, Mojo version, `-O3`, timer,
sample policy, fixture policy, allocation policy, and native `Float64` SIMD
width. It also names the external provenance fields that must accompany saved
output: CPU, OS, architecture, UTC timestamp, thermal state, system load, and
the exact command. Preserve that header and the unedited per-case lines when
comparing runs. The two convolution cells differ only in the selected SIMD or
scalar core and therefore provide a direct within-run speedup comparison.

On macOS, capture a real Time Profiler trace with symbols using:

```text
pixi run mojo build -I src -O3 -g1 benchmarks/bench_analysis.mojo -o .pixi/bench_analysis_profile
xcrun xctrace record --template 'Time Profiler' --launch -- ./.pixi/bench_analysis_profile
```

The 2026-08-22 Apple M4 baseline attributed 51.2% of sampled CPU to bounds
checks, 23.5% to insertion-sorted height priority, and 13.2% directly to
pairwise distance selection. The owning dense-peak case measured 42.664 ms p50
and 59.612 ms p95. After heap priority, neighborhood pruning, and indexed
prominence/width lookup, a quiet final run measured 1.988 ms p50 and 2.193 ms
p95 (21.5x and 27.2x respectively). The reusable path measured 1.984 ms p50 and
2.097 ms p95. The post-change trace no longer showed peak distance selection
among dominant frames.

The post-change profile then identified direct convolution as the dominant
regular arithmetic kernel. Native-width SIMD reduced the representative
Savitzky-Golay result from 7.605/8.210 ms p50/p95 to 2.012/2.429 ms in the same
baseline/final methodology (3.8x/3.4x). Welch remained essentially unchanged,
as intended: 3.069/3.511 ms before and 3.081/3.522 ms after. Numbers are
development evidence, not portable performance claims. Record CPU, OS, Mojo
version, compiler options, thermals/load, exact command, and raw output when
comparing changes.

The v3 harness was rerun for the 0.1.0 release candidate under the final exact
Mojo 1.0.0 and ShuhaFFT 0.1.0 lock. The checked-in
[raw result record](results/nami-analysis-v3-20260822.md) includes the exact UTC
timestamp and commands, dependency versions, CPU/OS/architecture, `pmset`
thermal and performance status, system load, unedited command stdout, commit,
lock hash, and executable source hashes. No new Time Profiler capture was needed
because the final run exposed no correctness change or unexplained
representative regression. This noisy, uncontrolled run validates the release
benchmark cells; it is not a portable performance claim.
