"""Dependency-free detrending for finite `Float64` sequences."""

from std.collections import List
from std.io import Writable, Writer
from std.math import isfinite


struct DetrendKind(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Select constant-mean or linear least-squares detrending.

    Direct mutation of `_value` is out of contract; use `validate()` for an
    explicit checkpoint after unusual mutation.
    """

    comptime CONSTANT = DetrendKind(0)
    comptime LINEAR = DetrendKind(1)

    var _value: Int

    def __init__(out self, _value: Int):
        self._value = _value

    def validate(self) raises:
        """Raise if unusual direct field mutation broke the kind invariant."""
        if self != Self.CONSTANT and self != Self.LINEAR:
            raise Error("invalid detrend kind")

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("CONSTANT" if self == Self.CONSTANT else "LINEAR")


def detrend(
    signal: Span[Float64, _],
    kind: DetrendKind = DetrendKind.LINEAR,
) raises -> List[Float64]:
    """Remove a constant mean or linear least-squares trend from `signal`.

    `LINEAR` fits the index axis `0 .. len(signal) - 1` with the closed-form
    slope `sum((i - mean_i) * (x_i - mean_x)) / sum((i - mean_i)^2)` and
    intercept `mean_x - slope * mean_i`. A singleton returns `[0.0]` for both
    kinds. This function allocates one output `List`; the input is preserved.
    Results match SciPy within `1e-12` on the committed fixtures.

    The input must be non-empty and contain only finite values.
    """
    if len(signal) == 0:
        raise Error("detrend input must be non-empty")

    var mean_x = 0.0
    for index in range(len(signal)):
        if not isfinite(signal[index]):
            raise Error("detrend input must contain only finite values")
        mean_x += signal[index]
    mean_x /= Float64(len(signal))

    var output = List[Float64](capacity=len(signal))
    if len(signal) == 1:
        output.append(0.0)
        return output^

    if kind == DetrendKind.CONSTANT:
        for index in range(len(signal)):
            output.append(signal[index] - mean_x)
        return output^

    var mean_i = Float64(len(signal) - 1) / 2.0
    var numerator = 0.0
    var denominator = 0.0
    for index in range(len(signal)):
        var centered_i = Float64(index) - mean_i
        numerator += centered_i * (signal[index] - mean_x)
        denominator += centered_i * centered_i
    var slope = numerator / denominator
    var intercept = mean_x - slope * mean_i
    for index in range(len(signal)):
        output.append(signal[index] - (intercept + slope * Float64(index)))
    return output^
