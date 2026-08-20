"""Hann, Hamming, and Blackman windows with explicit sampling semantics."""

from std.collections import List
from std.math import cos


struct WindowSampling(Copyable, Equatable, ImplicitlyCopyable):
    """Choose whether a window includes both endpoints of its sampled interval.

    `SYMMETRIC` includes both endpoints and is appropriate for filter design.
    `PERIODIC` omits the repeated endpoint and is appropriate for spectral work.
    """

    comptime SYMMETRIC = WindowSampling(periodic=False)
    comptime PERIODIC = WindowSampling(periodic=True)

    var _periodic: Bool

    def __init__(out self, *, periodic: Bool):
        """Construct one of the two valid sampling modes."""
        self._periodic = periodic

    def __eq__(self, other: Self) -> Bool:
        return self._periodic == other._periodic


struct WindowNormalization(Copyable, Equatable, ImplicitlyCopyable):
    """Choose whether to preserve formula values or rescale sampled values.

    `FORMULA` evaluates the conventional coefficients directly. `PEAK` divides
    by the largest sampled absolute value. It raises when all sampled values are
    numerically zero, because such a window has no meaningful peak to scale.
    """

    comptime FORMULA = WindowNormalization(peak=False)
    comptime PEAK = WindowNormalization(peak=True)

    var _peak: Bool

    def __init__(out self, *, peak: Bool):
        """Construct one of the two valid normalization modes."""
        self._peak = peak

    def __eq__(self, other: Self) -> Bool:
        return self._peak == other._peak


def _normalize_peak(mut values: List[Float64]) raises:
    var peak = 0.0
    for index in range(len(values)):
        peak = max(peak, abs(values[index]))
    # The supported formulas have coefficients of order one. Treat residuals at
    # this absolute scale as zero so endpoint roundoff is never amplified.
    if peak <= 1e-15:
        raise Error("cannot peak-normalize a numerically zero window")
    for index in range(len(values)):
        values[index] /= peak


def _general_cosine(
    length: Int,
    a0: Float64,
    a1: Float64,
    a2: Float64,
    sampling: WindowSampling,
    normalization: WindowNormalization,
) raises -> List[Float64]:
    if length < 0:
        raise Error("window length must be non-negative")
    if length == 0:
        return List[Float64]()
    if length == 1:
        return [1.0]

    var denominator = length if sampling == WindowSampling.PERIODIC else length - 1
    var result = List[Float64](capacity=length)
    for index in range(length):
        var phase = (
            6.283185307179586476925286766559 * Float64(index) / Float64(denominator)
        )
        result.append(a0 - a1 * cos(phase) + a2 * cos(2.0 * phase))

    if normalization == WindowNormalization.PEAK:
        _normalize_peak(result)
    return result^


def hann(
    length: Int,
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a Hann window of `length` samples.

    Zero length returns an empty list and length one returns `[1.0]`. Negative
    lengths raise. Peak normalization also raises when every sample is
    numerically zero. The default is the conventional symmetric formula.
    """
    return _general_cosine(length, 0.5, 0.5, 0.0, sampling, normalization)


def hamming(
    length: Int,
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a Hamming window of `length` samples.

    Zero length returns an empty list and length one returns `[1.0]`. Negative
    lengths raise. Peak normalization also raises when every sample is
    numerically zero. The default is the conventional symmetric formula.
    """
    return _general_cosine(length, 0.54, 0.46, 0.0, sampling, normalization)


def blackman(
    length: Int,
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a three-term Blackman window of `length` samples.

    Zero length returns an empty list and length one returns `[1.0]`. Negative
    lengths raise. Peak normalization also raises when every sample is
    numerically zero. The default coefficients are 0.42, 0.5, and 0.08.
    """
    return _general_cosine(length, 0.42, 0.5, 0.08, sampling, normalization)
