# Benchmarks

No performance result is published for the correctness-first direct convolution
slice. Its future benchmark matrix must separate signal length, kernel length,
and FULL/SAME/VALID mode, including at least short FIR-like kernels, equal-sized
inputs, and kernels long enough to expose quadratic scaling.

Record the CPU, OS, Mojo version, compiler options, dataset provenance, warmup,
iterations, statistic, allocation policy, and exact command.

Benchmark programs belong in `bench_*.mojo`. Results are development evidence,
not permanent marketing claims.
