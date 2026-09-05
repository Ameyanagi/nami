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
            raise Error(
                String(
                    (
                        "DetrendKind _value must be 0 (CONSTANT) or 1 (LINEAR); "
                        "got _value="
                    ),
                    self._value,
                )
            )

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        if self == Self.CONSTANT:
            writer.write("CONSTANT")
        elif self == Self.LINEAR:
            writer.write("LINEAR")
        else:
            writer.write("INVALID(_value=", self._value, ")")


def _scaled_mean(signal: Span[Float64, _]) -> Tuple[Float64, Float64]:
    """Return scale and compensated normalized mean for validated finite data."""
    var scale = 0.0
    for value in signal:
        scale = max(scale, abs(value))
    if scale == 0.0:
        return (1.0, 0.0)
    var total = 0.0
    var correction = 0.0
    for value in signal:
        var normalized = value / scale
        var updated = total + normalized
        if abs(total) >= abs(normalized):
            correction += (total - updated) + normalized
        else:
            correction += (normalized - updated) + total
        total = updated
    return (scale, (total + correction) / Float64(len(signal)))


def detrend(
    signal: Span[Float64, _],
    kind: DetrendKind = DetrendKind.LINEAR,
) raises -> List[Float64]:
    """Remove a constant mean or linear least-squares trend from `signal`.

    Scaled samples and a centered, normalized index axis keep the fit finite
    when the residual is representable, including near-maximum constants.
    Non-finite input or a residual outside finite Float64 raises. A singleton
    returns zero. The borrowed input is preserved; one output list is allocated.
    """
    kind.validate()
    if len(signal) == 0:
        raise Error("detrend signal must be non-empty; got signal_length=0")
    for index in range(len(signal)):
        if not isfinite(signal[index]):
            raise Error(
                String(
                    "detrend signal must contain only finite values; got signal[",
                    index,
                    "]=",
                    signal[index],
                )
            )

    var output = List[Float64](capacity=len(signal))
    if len(signal) == 1:
        output.append(0.0)
        return output^
    var statistics = _scaled_mean(signal)
    var scale = statistics[0]
    var mean = statistics[1]
    var slope = 0.0
    var mean_i = Float64(len(signal) - 1) / 2.0
    if kind == DetrendKind.LINEAR:
        var numerator = 0.0
        var correction = 0.0
        var denominator = 0.0
        for index in range(len(signal)):
            var axis = (Float64(index) - mean_i) / mean_i
            var term = axis * (signal[index] / scale - mean)
            var updated = numerator + term
            if abs(numerator) >= abs(term):
                correction += (numerator - updated) + term
            else:
                correction += (term - updated) + numerator
            numerator = updated
            denominator += axis * axis
        slope = (numerator + correction) / denominator

    for index in range(len(signal)):
        var axis = (Float64(index) - mean_i) / mean_i
        var residual = ((signal[index] / scale - mean) - slope * axis) * scale
        if not isfinite(residual):
            raise Error(
                String(
                    "detrend result[",
                    index,
                    "] is outside finite Float64; got ",
                    residual,
                    "; rescale the signal before detrending",
                )
            )
        output.append(residual)
    return output^
