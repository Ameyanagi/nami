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

The initial implementation materializes the full result before selecting SAME
or VALID. This establishes one deterministic numerical contract before later
work measures whether mode-specific allocation or SIMD kernels are warranted.
