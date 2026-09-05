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
`x[i] - (intercept + slope * i)`. The implementation divides samples by their
maximum absolute magnitude, uses compensated summation for the mean and fit,
and centers/scales the index axis to `[-1, 1]`. It computes residuals before
restoring the sample scale, avoiding overflowing sums, slopes, or intercepts.
No matrix solver is used.

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

Detrending allocates one output `List[Float64]` and preserves the borrowed
input. The implementation matches `scipy.signal.detrend` within `1e-12` on the
committed SciPy 1.16.1 fixtures.
