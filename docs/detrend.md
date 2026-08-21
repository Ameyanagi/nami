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

The returned sample at index `i` is
`x[i] - (intercept + slope * i)`. No matrix solver is used.

## Edge cases and errors

- A one-sample input returns `[0.0]` for both detrend kinds.
- An empty input raises.
- Every input sample must be finite; NaN and infinity raise.
- `DetrendKind` is an Int-backed nominal value. Direct `_value` mutation is out
  of contract; `validate()` provides an explicit invariant checkpoint.

## Ownership and tolerance

Detrending allocates one output `List[Float64]` and preserves the borrowed
input. The implementation matches `scipy.signal.detrend` within `1e-12` on the
committed SciPy 1.16.1 fixtures.
