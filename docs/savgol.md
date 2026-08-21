# Savitzky-Golay smoothing

`savgol_coefficients(window_length, poly_order, derivative, delta)` constructs
least-squares polynomial filter coefficients in `Float64`. It uses the
Gram-polynomial closed form and derivative recurrences described by
[Gorry (1990)](https://doi.org/10.1021/ac00205a007), with no matrix solver.

## Coefficient convention

The returned coefficients are ordered for convolution, matching
`scipy.signal.savgol_coeffs(..., use="conv")`. This is the reverse of the
natural left-to-right sample order used by a dot product. A derivative of order
`s` is scaled by `1 / delta**s`; the zero-order coefficients sum to one, while
positive-order coefficients annihilate constants up to floating-point error.

The window length must be odd and positive. The polynomial order must satisfy
`0 <= poly_order < window_length`, the derivative must satisfy
`0 <= derivative <= poly_order`, and `delta` must be positive and finite. Each
invalid-parameter diagnostic includes the supplied numeric values.

## Smoothing and edges

`savgol_filter(signal, window_length, poly_order)` provides smoothing only:
derivative zero and unit sample spacing. Interior samples use
`convolve(signal, coefficients, ConvolutionMode.SAME)`. Because the kernel is
odd, SAME centering is exact.

The first and last `window_length // 2` samples follow SciPy's default `interp`
policy. The first complete window is fit once mathematically and evaluated at
each leading position; the last complete window is treated the same way for
the trailing positions. Nami obtains each evaluation directly from the same
Gorry weights used at the center, with an off-center evaluation offset and no
padding or matrix solve. A polynomial whose degree is at most `poly_order` is
therefore reproduced at both edges as well as in the interior.

## Validation and allocation

- The signal length must be at least the window length.
- Every input sample must be finite.
- Dimension and input diagnostics include the offending lengths, index, or
  value.
- Inputs are preserved. Coefficient generation allocates a new owning list and
  temporary Gram-recurrence workspaces. Filtering additionally allocates the
  direct-convolution storage and returns a new owning list.

The committed SciPy 1.16.1 coefficient and filtering fixtures use a tolerance
of `1e-10`. SciPy's least-squares solver contributes reference noise around
`1e-12`, while the Gram closed form commonly produces cleaner rational values.
