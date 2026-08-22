# Nami analysis benchmark v3 release candidate — 2026-08-22

This is raw release-candidate evidence, not a portable performance claim.

## Provenance

- UTC benchmark timestamp: `2026-08-22T04:10:24Z`
- CPU: Apple M4
- architecture: `arm64`
- OS: macOS 26.5.1 (25F80)
- Mojo package: `mojo` 1.0.0 `release`
- compiler package: `mojo-compiler` 1.0.0 `release`
- FFT dependency: `mojo-shuhafft` 0.1.0 `h60d57d3_0` from the public
  `https://ameyanagi.github.io/mojo-channel` channel
- compiler command: `mojo build -O3`
- benchmark policy: three warmups and p50/p95 over 31 timed samples
- one/five/fifteen-minute load averages: `4.62/4.84/4.71`
- thermal observation from `pmset -g therm`: no thermal warning level, no
  performance warning level, and no CPU power status had been recorded
- benchmark input commit: `aa1ffae7d00569ad6b40771b4361f2a1d58f094c`
- tracked worktree at execution: clean
- exact `pixi.lock` SHA-256:
  `8ab6dee590d11236ce72d522157776d7c4dd1f6192870965ddf0517a627df51a`

The result record is necessarily committed after the benchmark input commit.
Only documentation changes follow that input commit; every executable source
and dependency-lock input is hashed below.

```text
163ddf3fe6c10a063fc5ae383904394a3d47b8a71f764da7489cc9f49bc57dec  benchmarks/bench_analysis.mojo
7778258e24aae83d449f7e2f1ffe5322b17ba5cc6124bb2c1cda46fca24ccbb0  src/nami/convolution.mojo
7660c246c475d28a10d23bb08222af304eabb2086efc875ec7aa78b77641014c  src/nami/peaks.mojo
64f6f00cc3115e8aa238f591df1159c2df815eeb1a6e32bbbfd75e34e34b83df  src/nami/spectral/psd.mojo
8ab6dee590d11236ce72d522157776d7c4dd1f6192870965ddf0517a627df51a  pixi.lock
```

## Exact commands

Build:

```sh
pixi run --locked mojo build -I src -O3 benchmarks/bench_analysis.mojo -o .pixi/bench_analysis
```

System context, exact installed dependency versions, and benchmark run:

```sh
date -u '+utc=%Y-%m-%dT%H:%M:%SZ'; sysctl -n machdep.cpu.brand_string; uname -m; sw_vers; pmset -g therm; uptime; pixi list | rg '^(mojo|mojo-compiler|mojo-shuhafft)[[:space:]]'; ./.pixi/bench_analysis
```

## Raw command stdout

```text
utc=2026-08-22T04:10:24Z
Apple M4
arm64
ProductName:		macOS
ProductVersion:		26.5.1
BuildVersion:		25F80
Note: No thermal warning level has been recorded
Note: No performance warning level has been recorded
Note: No CPU power status has been recorded
 13:10:24  up 60 days  9:54,  2 users,  load average: 4.62, 4.84, 4.71
Installed for: osx-arm64
mojo                  1.0.0         release              96.47 MiB  conda  https://conda.modular.com/max
mojo-compiler         1.0.0         release              58.38 MiB  conda  https://conda.modular.com/max
mojo-shuhafft         0.1.0         h60d57d3_0          140.42 KiB  conda  https://ameyanagi.github.io/mojo-channel
schema=nami-analysis-benchmark-v3 mojo=1.0.0 compiler=mojo-build-O3 timer=perf_counter_ns samples=31 warmups=3 fixture=deterministic allocation=case-specific
provenance_required=cpu,os,architecture,utc,thermal_state,system_load,exact_command native_float64_simd_width=2
case=convolve_core_simd_n65536_k31_same p50_ns=715000 p95_ns=1643000 checksum=-3.090109699239022
case=convolve_core_scalar_n65536_k31_same p50_ns=3122000 p95_ns=3134000 checksum=-3.090109699239022
case=savgol_n65536_w31 p50_ns=910000 p95_ns=920000 checksum=6.219584382335073e-13
case=welch_n65536_segment256 p50_ns=1316000 p95_ns=1329000 checksum=1.4282406233324397e-11
case=find_peaks_n8192_dense_distance4 p50_ns=848000 p95_ns=868000 checksum=56383.868756121454
case=find_peaks_into_n8192_reused p50_ns=849000 p95_ns=899000 checksum=56383.868756121454
```

## Interpretation and profiling decision

The semantic checksums exactly match the earlier v3 run. On this uncontrolled
sample, native SIMD convolution is 4.37x faster at p50 and 1.91x faster at p95
than the scalar reference. The owning and reusable peak paths remain within
normal run-to-run noise of one another.

No new Time Profiler capture was needed: the final locked run exposed no
correctness change or unexplained representative regression requiring another
optimization investigation. Historical profiler-led optimization evidence is
retained in the benchmark methodology; this record is the authoritative raw
release-candidate timing run.
