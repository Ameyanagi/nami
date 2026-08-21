"""Savitzky-Golay coefficients and smoothing for finite `Float64` data."""

from .convolution import ConvolutionMode, convolve
from std.collections import List
from std.math import isfinite


def _validate_savgol_parameters(
    window_length: Int,
    poly_order: Int,
    derivative: Int,
    delta: Float64,
) raises:
    if window_length <= 0 or window_length % 2 == 0:
        raise Error(
            String(
                "savgol window_length must be odd and positive; got window_length=",
                window_length,
            )
        )
    if poly_order < 0 or poly_order >= window_length:
        raise Error(
            String(
                (
                    "savgol poly_order must satisfy 0 <= poly_order < "
                    "window_length; got poly_order="
                ),
                poly_order,
                ", window_length=",
                window_length,
            )
        )
    if derivative < 0 or derivative > poly_order:
        raise Error(
            String(
                (
                    "savgol derivative must satisfy 0 <= derivative <= "
                    "poly_order; got derivative="
                ),
                derivative,
                ", poly_order=",
                poly_order,
            )
        )
    if delta <= 0.0 or not isfinite(delta):
        raise Error(
            String("savgol delta must be positive and finite; got delta=", delta)
        )


def _gram_table(
    half_window: Int,
    position: Int,
    max_order: Int,
    max_derivative: Int,
) -> List[Float64]:
    """Tabulate Gorry's Gram recurrence through the requested derivative."""
    var stride = max_derivative + 1
    # Row zero represents P_-1 and row one represents P_0.
    var values = List[Float64](
        length=(max_order + 2) * stride,
        fill=0.0,
    )
    values[stride] = 1.0
    for order in range(1, max_order + 1):
        var denominator = Float64(order) * Float64(2 * half_window - order + 1)
        var first_factor = 2.0 * Float64(2 * order - 1) / denominator
        var second_factor = (
            Float64(order - 1) * Float64(2 * half_window + order) / denominator
        )
        var current_base = (order + 1) * stride
        var previous_base = order * stride
        var previous_previous_base = (order - 1) * stride
        for current_derivative in range(max_derivative + 1):
            var recurrence = (
                Float64(position) * values[previous_base + current_derivative]
            )
            if current_derivative > 0:
                recurrence += (
                    Float64(current_derivative)
                    * values[previous_base + current_derivative - 1]
                )
            values[current_base + current_derivative] = (
                first_factor * recurrence
                - second_factor * values[previous_previous_base + current_derivative]
            )
    return values^


def _savgol_weight(
    sample_offset: Int,
    evaluation_offset: Int,
    half_window: Int,
    poly_order: Int,
    derivative: Int,
) -> Float64:
    """Return one natural-order Gorry least-squares evaluation weight."""
    var sample_grams = _gram_table(half_window, sample_offset, poly_order, 0)
    var evaluation_grams = _gram_table(
        half_window,
        evaluation_offset,
        poly_order,
        derivative,
    )
    var evaluation_stride = derivative + 1
    # A(2m, 0) / A(2m + 1, 1).
    var factorial_ratio = 1.0 / Float64(2 * half_window + 1)
    var weight = 0.0
    for order in range(poly_order + 1):
        var sample_gram = sample_grams[order + 1]
        var evaluation_gram = evaluation_grams[
            (order + 1) * evaluation_stride + derivative
        ]
        weight += (
            Float64(2 * order + 1) * factorial_ratio * sample_gram * evaluation_gram
        )
        # Advance A(2m, k) / A(2m + k + 1, k + 1) without forming
        # either potentially large generalized factorial.
        factorial_ratio *= Float64(2 * half_window - order) / Float64(
            2 * half_window + order + 2
        )
    return weight


def savgol_coefficients(
    window_length: Int,
    poly_order: Int,
    derivative: Int = 0,
    delta: Float64 = 1.0,
) raises -> List[Float64]:
    """Return convolution-order Savitzky-Golay coefficients.

    The Gorry Gram-polynomial closed form evaluates the requested derivative at
    the window center without a matrix solver. Coefficients are reversed from
    natural sample order for direct use with `convolve` and are scaled by
    `1 / delta**derivative`. A new owning `List` is allocated.

    `window_length` must be odd and positive, `poly_order` must be non-negative
    and less than the window length, `derivative` must be between zero and the
    polynomial order, and `delta` must be positive and finite.
    """
    _validate_savgol_parameters(
        window_length,
        poly_order,
        derivative,
        delta,
    )
    var derivative_scale = 1.0
    for _ in range(derivative):
        derivative_scale /= delta

    var half_window = window_length // 2
    var coefficients = List[Float64](capacity=window_length)
    for index in range(window_length):
        var natural_offset = half_window - index
        coefficients.append(
            derivative_scale
            * _savgol_weight(
                natural_offset,
                0,
                half_window,
                poly_order,
                derivative,
            )
        )
    return coefficients^


def _edge_value(
    signal: Span[Float64, _],
    window_start: Int,
    half_window: Int,
    poly_order: Int,
    evaluation_offset: Int,
) -> Float64:
    var value = 0.0
    var window_length = 2 * half_window + 1
    for index in range(window_length):
        value += signal[window_start + index] * _savgol_weight(
            index - half_window,
            evaluation_offset,
            half_window,
            poly_order,
            0,
        )
    return value


def savgol_filter(
    signal: Span[Float64, _],
    window_length: Int,
    poly_order: Int,
) raises -> List[Float64]:
    """Smooth `signal` with centered Savitzky-Golay least-squares fits.

    The interior uses direct SAME convolution. The first and last half-window
    samples use Gorry weights that evaluate the polynomial fitted to the first
    or last complete window, matching SciPy's default `interp` edge policy.
    Results match the committed SciPy fixtures within `1e-10`.

    The input must contain at least `window_length` finite samples. This function
    preserves it and allocates coefficients, convolution storage, and Gram
    recurrence workspaces before returning a new owning `List`.
    """
    _validate_savgol_parameters(window_length, poly_order, 0, 1.0)
    if len(signal) < window_length:
        raise Error(
            String(
                (
                    "savgol_filter requires signal length >= window_length; "
                    "got signal_length="
                ),
                len(signal),
                ", window_length=",
                window_length,
            )
        )
    for index in range(len(signal)):
        if not isfinite(signal[index]):
            raise Error(
                String(
                    "savgol_filter input must contain only finite values; got signal[",
                    index,
                    "]=",
                    signal[index],
                )
            )

    var coefficients = savgol_coefficients(window_length, poly_order)
    var output = convolve(signal, coefficients, ConvolutionMode.SAME)
    var half_window = window_length // 2
    for index in range(half_window):
        output[index] = _edge_value(
            signal,
            0,
            half_window,
            poly_order,
            index - half_window,
        )

    var last_window_start = len(signal) - window_length
    for edge_index in range(half_window):
        var output_index = len(signal) - half_window + edge_index
        output[output_index] = _edge_value(
            signal,
            last_window_start,
            half_window,
            poly_order,
            output_index - last_window_start - half_window,
        )
    return output^
