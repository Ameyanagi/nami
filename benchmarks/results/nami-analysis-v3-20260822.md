# Nami analysis benchmark v3 — 2026-08-22

This is raw development evidence, not a portable performance claim.

## Provenance

- UTC benchmark timestamp: `2026-08-22T00:33:02Z`
- profiler interval: `2026-08-22T09:32:20.243+09:00` through
  `2026-08-22T09:32:21.815+09:00`
- CPU: Apple M4
- architecture: `arm64`
- OS: macOS 26.5.1 (25F80)
- Mojo: 1.0.0
- compiler: `mojo build -O3`; profiler build additionally used `-g1`
- one/five/fifteen-minute load averages: `5.21/5.11/5.44`
- thermal observation from `pmset -g therm`: no thermal warning level, no
  performance warning level, and no CPU power status had been recorded
- repository HEAD: `fe435d28e313df32eae63c90d9d64ee5f008eada`

The measured worktree was intentionally uncommitted. Exact input hashes:

```text
163ddf3fe6c10a063fc5ae383904394a3d47b8a71f764da7489cc9f49bc57dec  benchmarks/bench_analysis.mojo
7778258e24aae83d449f7e2f1ffe5322b17ba5cc6124bb2c1cda46fca24ccbb0  src/nami/convolution.mojo
7660c246c475d28a10d23bb08222af304eabb2086efc875ec7aa78b77641014c  src/nami/peaks.mojo
64f6f00cc3115e8aa238f591df1159c2df815eeb1a6e32bbbfd75e34e34b83df  src/nami/spectral/psd.mojo
904703a12d6dc043334d9848c63fd0503ea01e1d14e1abb0854649b57dcc084a  pixi.lock
```

## Exact benchmark command

```sh
pixi run mojo build -I src -O3 benchmarks/bench_analysis.mojo -o .pixi/bench_analysis
date -u '+utc=%Y-%m-%dT%H:%M:%SZ'; pmset -g therm; uptime; ./.pixi/bench_analysis
```

## Raw benchmark stdout

```text
utc=2026-08-22T00:33:02Z
Note: No thermal warning level has been recorded
Note: No performance warning level has been recorded
Note: No CPU power status has been recorded
 09:33:02  up 60 days  6:17,  2 users,  load average: 5.21, 5.11, 5.44
schema=nami-analysis-benchmark-v3 mojo=1.0.0 compiler=mojo-build-O3 timer=perf_counter_ns samples=31 warmups=3 fixture=deterministic allocation=case-specific
provenance_required=cpu,os,architecture,utc,thermal_state,system_load,exact_command native_float64_simd_width=2
case=convolve_core_simd_n65536_k31_same p50_ns=971000 p95_ns=1124000 checksum=-3.090109699239022
case=convolve_core_scalar_n65536_k31_same p50_ns=4751000 p95_ns=4774000 checksum=-3.090109699239022
case=savgol_n65536_w31 p50_ns=1386000 p95_ns=1396000 checksum=6.219584382335073e-13
case=welch_n65536_segment256 p50_ns=2081000 p95_ns=2100000 checksum=1.4282406233324397e-11
case=find_peaks_n8192_dense_distance4 p50_ns=1296000 p95_ns=1387000 checksum=56383.868756121454
case=find_peaks_into_n8192_reused p50_ns=1295000 p95_ns=1393000 checksum=56383.868756121454
```

## Time Profiler capture

Exact command:

```sh
pixi run mojo build -I src -O3 -g1 benchmarks/bench_analysis.mojo -o .pixi/bench_analysis_profile
xcrun xctrace record --template 'Time Profiler' --output /tmp/nami-analysis-v3-20260822.trace --launch -- ./.pixi/bench_analysis_profile
xcrun xctrace export --input /tmp/nami-analysis-v3-20260822.trace --toc --output /tmp/nami-analysis-v3-20260822-toc.xml
```

Xcode Instruments 26.0 recorded the successful process for 1.571943 seconds.
The 11 MiB trace bundle contains 213 files and is not committed. Its canonical
sorted `(SHA-256, relative path)` manifest hashes to
`414a381447fc635f28106b8dba6f259cffd8eedc3571f18d5bc19b701036d6ca`.
The exported TOC hashes to
`8986af84126d19889554c2fc720905fe10a97dc74acc4fe034f13259b7daccd9`.
