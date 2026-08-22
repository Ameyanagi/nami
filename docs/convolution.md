# Direct convolution

`convolve(signal, kernel, mode)` computes discrete linear convolution directly
in `Float64`. It depends only on the Mojo standard library and performs
`signal_length * kernel_length` multiply-add steps.

## Output modes

`ConvolutionMode.FULL` returns all `N + M - 1` samples and is the default.

`ConvolutionMode.SAME` returns `N` samples, where `N` is the length of
`signal`, the first input. Its first returned sample has full-output index
`floor((M - 1) / 2)`. This is the left-centered convention for an even-length
kernel.

`ConvolutionMode.VALID` returns `N - M + 1` samples beginning at full-output
index `M - 1`. It requires `M <= N`: Nami treats the first input as the signal
and the second as the kernel rather than silently swapping their roles.

## Validation and ownership

- Both inputs must be non-empty.
- Every input sample must be finite.
- Every accumulated output must remain finite; multiplication or accumulation
  overflow raises instead of returning infinity or NaN.
- `N + M - 1` must fit in `Int`, including for sliced modes.
- `ConvolutionMode` is an Int-backed nominal value. Direct `_value` mutation is
  out of contract; `validate()` provides an explicit invariant checkpoint.
- The inputs are preserved and a new owning `List[Float64]` is returned.

The direct kernel accumulates complete native-SIMD-width kernel chunks into
contiguous output chunks, followed by a scalar tail. Accumulation still visits
signal samples in increasing order, preserving the scalar reference's update
order for every output element. Each vector result is checked for finiteness;
the failing output index is reported exactly as on the scalar tail. The full
result is materialized before selecting SAME or VALID.

The unsafe loads and stores form a narrow internal boundary: validation has
already established non-empty live spans, vector bounds are rounded down to a
complete native width, and the full output has length `N + M - 1`. Differential
tests compare chunks and tails against the retained scalar reference and cover
overflow on the vector path.

## Correlation

`correlate(signal, kernel, mode)` computes direct cross-correlation without
complex conjugation. For every output mode, its definition is

```text
correlate(a, b, mode) == convolve(a, reversed(b), mode)
```

This relationship also determines the centering of `SAME` for even-length
kernels.

For a kernel of length `M`, full-output index `m` represents lag
`m - (M - 1)`. The value at lag `k` is

```text
sum_n signal[n + k] * kernel[n]
```

where the sum includes only indices present in both inputs. Zero lag is at
full-output index `M - 1`; positive lag means the signal is shifted toward
larger indices relative to the kernel.

The `FULL`, `SAME`, and `VALID` slices have exactly the convolution semantics
documented above. In particular, `SAME` returns the signal length with the
left-centered even-kernel convention, and `VALID` requires the kernel length
to be no greater than the signal length.

Correlation has the same error contract as convolution: inputs must be
non-empty and finite, `N + M - 1` must fit in `Int`, every accumulated result
must remain finite, and invalid `VALID` dimensions raise with both lengths in
the diagnostic. Correlation preserves both inputs and allocates a reversed
kernel plus the convolution result.
