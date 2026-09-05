# Detrending

`detrend(signal, kind)` removes either a constant mean or a linear
least-squares trend from a finite `Float64` sequence. The default is
`DetrendKind.LINEAR`.

## Semantics

`DetrendKind.CONSTANT` subtracts the arithmetic mean from every input sample.

`DetrendKind.LINEAR` fits a line against the index axis `0 .. N - 1`. With
`mean_i` as the mean index and `mean_x` as the mean sample value, the fit is
computed directly as

```text
slope = sum((i - mean_i) * (x[i] - mean_x))
        / sum((i - mean_i) * (i - mean_i))
intercept = mean_x - slope * mean_i
```

The returned sample at index `i` is mathematically
`x[i] - (intercept + slope * i)`. The implementation scales by a power of two,
which preserves the input significands, and retains sums in bounded floating-point
expansions. It evaluates the residual numerator before division, so a large
rounded mean or fitted line cannot erase a small answer through cancellation.
For constant detrending the numerator is `N*x[i] - sum(x)`. For linear detrending,
with `d[i] = 2*i - (N-1)`, `Sd = sum(d*x)`, and `D2 = sum(d*d)`, it evaluates
`((N*x[i] - sum(x))*D2 - N*d[i]*Sd) / (N*D2)`. Fused multiply-add remainders
preserve product rounding terms until the numerator is complete.

When nonzero inputs span more than 512 encoded binary exponents, a single scale
would lose tiny but representable residuals after cancellation. The implementation
then applies the same linear operation separately to eight fixed exponent bands,
treating other values as zero on the original index axis. It combines expanded
residual numerators with explicit exponent tags before the common final division.
Neither means nor individual band residuals are rounded before cancellation. Each band spans at most 307 binary exponents,
including subnormals, and all overflow-relevant large values share the highest
band. This retains both the tiny residual of `[1e308, -1e308, 1e-308]` and small
perturbations hidden beneath a large mean. No matrix solver is used.

## Edge cases and errors

- A one-sample input returns `[0.0]` for both detrend kinds.
- An empty input raises.
- Every input sample must be finite; NaN and infinity raise.
- A residual larger than finite `Float64` raises an error identifying its index
  and suggesting input rescaling. Representable subnormal residuals are allowed;
  smaller results follow normal Float64 rounding, including underflow to zero.
- `DetrendKind` is an Int-backed nominal value. Direct `_value` mutation is out
  of contract; `validate()` provides an explicit invariant checkpoint.

## Ownership and tolerance

Detrending allocates one output `List[Float64]` and a fixed table of at most
eight fits, preserving the borrowed input. Each expansion uses fixed inline
storage; there is no signal-sized allocation per band. The implementation
matches `scipy.signal.detrend` within `1e-12` on the committed SciPy 1.16.1
fixtures. Extreme regressions use scale-relative comparisons and exact powers
of two, including near-maximum adjacent values and subnormal residuals.
