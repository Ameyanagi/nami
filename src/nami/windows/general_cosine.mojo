"""General cosine windows with explicit sampling and normalization semantics."""

from std.collections import List
from std.io import Writable, Writer
from std.math import cos, pi


struct WindowSampling(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Choose whether a window includes both endpoints of its sampled interval.

    `SYMMETRIC` includes both endpoints and is appropriate for filter design.
    `PERIODIC` omits the repeated endpoint and is appropriate for spectral work.
    Direct mutation of `_value` is out of contract; use `validate()` for an
    explicit checkpoint after unusual mutation.
    """

    comptime SYMMETRIC = WindowSampling(0)
    comptime PERIODIC = WindowSampling(1)

    var _value: Int

    def __init__(out self, _value: Int):
        self._value = _value

    def validate(self) raises:
        """Raise if unusual direct field mutation broke the mode invariant."""
        if self != Self.SYMMETRIC and self != Self.PERIODIC:
            raise Error("invalid window sampling")

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("SYMMETRIC" if self == Self.SYMMETRIC else "PERIODIC")


struct WindowNormalization(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Choose whether to preserve formula values or rescale sampled values.

    `FORMULA` evaluates the conventional coefficients directly. `PEAK` divides
    by the largest sampled absolute value. It raises when all sampled values are
    numerically zero, because such a window has no meaningful peak to scale.
    Direct mutation of `_value` is out of contract; use `validate()` for an
    explicit checkpoint after unusual mutation.
    """

    comptime FORMULA = WindowNormalization(0)
    comptime PEAK = WindowNormalization(1)

    var _value: Int

    def __init__(out self, _value: Int):
        self._value = _value

    def validate(self) raises:
        """Raise if unusual direct field mutation broke the mode invariant."""
        if self != Self.FORMULA and self != Self.PEAK:
            raise Error("invalid window normalization")

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("FORMULA" if self == Self.FORMULA else "PEAK")


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


def general_cosine(
    length: Int,
    coefficients: Span[Float64, _],
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a weighted cosine-series window using SciPy's convention.

    Coefficients are centered on the origin: positive coefficients alternate
    signs when the same formula is written over a phase interval from zero to
    two pi. Zero length returns an empty list and length one returns `[1.0]`.
    """
    if length < 0:
        raise Error("window length must be non-negative")
    if length == 0:
        return List[Float64]()
    if length == 1:
        return [1.0]

    var denominator = length if sampling == WindowSampling.PERIODIC else length - 1
    var result = List[Float64](capacity=length)
    for index in range(length):
        var phase = -pi + 2.0 * pi * Float64(index) / Float64(denominator)
        var value = 0.0
        for coefficient_index in range(len(coefficients)):
            value += coefficients[coefficient_index] * cos(
                Float64(coefficient_index) * phase
            )
        result.append(value)

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
    var coefficients: List[Float64] = [0.5, 0.5]
    return general_cosine(length, coefficients, sampling, normalization)


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
    var coefficients: List[Float64] = [0.54, 0.46]
    return general_cosine(length, coefficients, sampling, normalization)


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
    var coefficients: List[Float64] = [0.42, 0.5, 0.08]
    return general_cosine(length, coefficients, sampling, normalization)


def nuttall(
    length: Int,
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a minimum four-term Blackman-Harris Nuttall window.

    Zero length returns an empty list and length one returns `[1.0]`. Negative
    lengths raise. Peak normalization also raises when every sample is
    numerically zero. The coefficients match SciPy's published constants.
    """
    var coefficients: List[Float64] = [0.3635819, 0.4891775, 0.1365995, 0.0106411]
    return general_cosine(length, coefficients, sampling, normalization)


def blackman_harris(
    length: Int,
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a minimum four-term Blackman-Harris window.

    Zero length returns an empty list and length one returns `[1.0]`. Negative
    lengths raise. Peak normalization also raises when every sample is
    numerically zero. The coefficients match SciPy's published constants.
    """
    var coefficients: List[Float64] = [0.35875, 0.48829, 0.14128, 0.01168]
    return general_cosine(length, coefficients, sampling, normalization)


def flattop(
    length: Int,
    sampling: WindowSampling = WindowSampling.SYMMETRIC,
    normalization: WindowNormalization = WindowNormalization.FORMULA,
) raises -> List[Float64]:
    """Return a flat-top amplitude-calibration window.

    Negative samples are expected for this amplitude-calibration window. Peak
    normalization uses the largest sampled absolute value. Zero length returns
    an empty list and length one returns `[1.0]`; negative lengths raise. The
    coefficients match SciPy's published constants.
    """
    var coefficients: List[Float64] = [
        0.21557895,
        0.41663158,
        0.277263158,
        0.083578947,
        0.006947368,
    ]
    return general_cosine(length, coefficients, sampling, normalization)
