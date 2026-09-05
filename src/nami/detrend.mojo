"""Dependency-free detrending for finite `Float64` sequences."""

from std.collections import InlineArray, List
from std.io import Writable, Writer
from std.math import fma, inf, isfinite, ldexp
from std.memory import bitcast


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


def _exponent_band(value: Float64) -> Int:
    """Group finite binary64 values into eight bounded exponent ranges."""
    var bits = bitcast[DType.uint64](value)
    return Int((bits >> 52) & UInt64(0x7FF)) // 256


struct _Expansion(Copyable):
    """Nonoverlapping partials; bounded binary64 exponents need <64 slots.

    Callers use normalized inputs and index products below 8*Int.MAX^4,
    so intermediate products and sums remain finite. Error-free two-sum and
    fused product remainders retain cancellation terms until final division.
    """

    var partials: InlineArray[Float64, 64]
    var count: Int

    def __init__(out self):
        self.partials = InlineArray[Float64, 64](fill=0.0)
        self.count = 0

    def add(mut self, value: Float64):
        var x = value
        var count = 0
        for index in range(self.count):
            var y = self.partials[index]
            if abs(x) < abs(y):
                var temporary = x
                x = y
                y = temporary
            var high = x + y
            var low = y - (high - x)
            if low != 0.0:
                self.partials[count] = low
                count += 1
            x = high
        if x != 0.0:
            debug_assert(count < 64, "normalized expansion fits bounded storage")
            self.partials[count] = x
            count += 1
        self.count = count

    def add_product(mut self, left: Float64, right: Float64):
        var high = left * right
        self.add(high)
        self.add(fma(left, right, -high))

    def value(self) -> Float64:
        var total = 0.0
        for index in range(self.count):
            total += self.partials[index]
        return total


def _power_of_two_scale(value: Float64) -> Float64:
    """Return the largest representable power of two <= a positive value."""
    var bits = bitcast[DType.uint64](value)
    var exponent_bits = bits & UInt64(0x7FF0_0000_0000_0000)
    if exponent_bits != 0:
        return bitcast[DType.float64](exponent_bits)
    var leading = UInt64(1)
    var cursor = bits
    while cursor > 1:
        cursor >>= 1
        leading <<= 1
    return bitcast[DType.float64](leading)


def _power_exponent(power: Float64) -> Int:
    var bits = bitcast[DType.uint64](power)
    var exponent = Int(bits >> 52)
    if exponent != 0:
        return exponent - 1023
    var result = -1074
    while bits > 1:
        bits >>= 1
        result += 1
    return result


@fieldwise_init
struct _ScaledPartial(Copyable, ImplicitlyCopyable):
    var value: Float64
    var exponent: Int


def _normalized_partial(value: Float64, exponent: Int) -> _ScaledPartial:
    if value == 0.0:
        return _ScaledPartial(0.0, 0)
    var scale = _power_of_two_scale(abs(value))
    return _ScaledPartial(value / scale, exponent + _power_exponent(scale))


def _restore_partial(value: Float64, exponent: Int) -> Float64:
    if value == 0.0:
        return 0.0
    var part = _normalized_partial(value, exponent)
    if part.exponent > 1023:
        return inf[DType.float64]() if part.value > 0.0 else -inf[DType.float64]()
    if part.exponent < -1075:
        return 0.0
    # Mojo 1.0 ldexp expects the power itself to be normal and finite.
    if part.exponent < -1022:
        return ldexp(part.value, Int32(part.exponent + 1022)) * 2.2250738585072014e-308
    return ldexp(part.value, Int32(part.exponent))


struct _ScaledExpansion:
    """Expanded numerators in original units, without Float64 exponent limits.

    Raw input quantum is at least 2^-1074 and index products add fewer than 260
    high exponent bits. Sixty-four nonoverlapping binary64 partials therefore
    cover the bounded numerator range. Distant terms remain separate until a
    cancellation makes them significant. No partial is divided or restored.
    """

    var partials: InlineArray[_ScaledPartial, 64]
    var count: Int

    def __init__(out self):
        self.partials = InlineArray[_ScaledPartial, 64](fill=_ScaledPartial(0.0, 0))
        self.count = 0

    def add(mut self, value: Float64, exponent: Int):
        var x = _normalized_partial(value, exponent)
        var count = 0
        for index in range(self.count):
            var y = self.partials[index]
            if x.value == 0.0:
                x = y
                continue
            if x.exponent < y.exponent or (
                x.exponent == y.exponent and abs(x.value) < abs(y.value)
            ):
                var temporary = x
                x = y
                y = temporary
            var difference = x.exponent - y.exponent
            if difference > 54:
                self.partials[count] = y
                count += 1
                continue
            var aligned = ldexp(y.value, Int32(-difference))
            var high = x.value + aligned
            var low = aligned - (high - x.value)
            if low != 0.0:
                self.partials[count] = _normalized_partial(low, x.exponent)
                count += 1
            x = _normalized_partial(high, x.exponent)
        if x.value != 0.0:
            debug_assert(count < 64, "scaled numerator fits bounded storage")
            self.partials[count] = x
            count += 1
        self.count = count

    def divided_value(self, divisor: Float64) -> Float64:
        if self.count == 0:
            return 0.0
        var exponent = self.partials[self.count - 1].exponent
        var total = 0.0
        for index in range(self.count):
            var part = self.partials[index]
            total += _restore_partial(part.value, part.exponent - exponent)
        return _restore_partial(total / divisor, exponent)


@fieldwise_init
struct _BandFit(Copyable):
    var band: Int
    var scale: Float64
    var total: _Expansion
    var weighted: _Expansion


def _fit_band(signal: Span[Float64, _], kind: DetrendKind, band: Int) -> _BandFit:
    var maximum = 0.0
    for value in signal:
        if band == -1 or _exponent_band(value) == band:
            maximum = max(maximum, abs(value))
    var total = _Expansion()
    var weighted = _Expansion()
    if maximum == 0.0:
        return _BandFit(band, 0.0, total^, weighted^)
    var scale = _power_of_two_scale(maximum)
    for index in range(len(signal)):
        var value = signal[index]
        if band != -1 and _exponent_band(value) != band:
            continue
        var normalized = value / scale
        total.add(normalized)
        if kind == DetrendKind.LINEAR:
            var axis = 2.0 * Float64(index) - Float64(len(signal) - 1)
            weighted.add_product(axis, normalized)
    return _BandFit(band, scale, total^, weighted^)


def _detrend_fitted(
    signal: Span[Float64, _], kind: DetrendKind, wide_range: Bool
) raises -> List[Float64]:
    """Evaluate residual numerators before rounding means or fitted lines.

    CONSTANT uses (N*x-S)/N. LINEAR uses
    ((N*x-S)*D2-N*d*Sd)/(N*D2), where d=2*i-(N-1), Sd=sum(d*x),
    and D2=sum(d*d). Expansions retain cancellation through the numerator.

    Wide ranges use fixed bands spanning <=307 exponents. Their expanded
    numerators are combined with explicit exponents before common division;
    partial fits are never materialized as rounded or overflowing residuals.
    """
    var fits = List[_BandFit](capacity=8 if wide_range else 1)
    for slot in range(8 if wide_range else 1):
        var fit = _fit_band(signal, kind, slot if wide_range else -1)
        if fit.scale != 0.0:
            fits.append(fit^)
    var length = Float64(len(signal))
    var denominator = _Expansion()
    if kind == DetrendKind.LINEAR:
        for index in range(len(signal)):
            var axis = 2.0 * Float64(index) - Float64(len(signal) - 1)
            denominator.add_product(axis, axis)
    var divisor = length * denominator.value() if kind == DetrendKind.LINEAR else length
    var output = List[Float64](capacity=len(signal))
    for index in range(len(signal)):
        var axis = 2.0 * Float64(index) - Float64(len(signal) - 1)
        var coefficient = _Expansion()
        if kind == DetrendKind.LINEAR:
            coefficient.add_product(length, axis)
        var value_band = _exponent_band(signal[index])
        var combined = _ScaledExpansion()
        for fit in fits:
            var normalized = (
                signal[index] / fit.scale if fit.band == -1
                or value_band == fit.band else 0.0
            )
            var centered = _Expansion()
            centered.add_product(length, normalized)
            for part in range(fit.total.count):
                centered.add(-fit.total.partials[part])
            var numerator = _Expansion()
            if kind == DetrendKind.LINEAR:
                for part in range(centered.count):
                    for factor in range(denominator.count):
                        numerator.add_product(
                            centered.partials[part], denominator.partials[factor]
                        )
                for part in range(fit.weighted.count):
                    for factor in range(coefficient.count):
                        numerator.add_product(
                            -fit.weighted.partials[part], coefficient.partials[factor]
                        )
            else:
                numerator = centered^
            var exponent = _power_exponent(fit.scale)
            for part in range(numerator.count):
                combined.add(numerator.partials[part], exponent)
        var residual = combined.divided_value(divisor)
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


def detrend(
    signal: Span[Float64, _],
    kind: DetrendKind = DetrendKind.LINEAR,
) raises -> List[Float64]:
    """Remove a constant mean or linear least-squares trend from `signal`.

    Power-of-two scaling and expanded residual numerators keep cancellation
    terms until final division, including tiny residuals near maximum constants.
    Non-finite input or a residual outside finite Float64 raises. A singleton
    returns zero. The borrowed input is preserved. An unusually wide exponent
    range uses eight bounded bands plus compensated residual combination to
    retain tiny cancellation terms; its additional fit storage has fixed size.
    """
    kind.validate()
    if len(signal) == 0:
        raise Error("detrend signal must be non-empty; got signal_length=0")
    var minimum_exponent = 2046
    var maximum_exponent = 0
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
        if signal[index] != 0.0:
            var bits = bitcast[DType.uint64](signal[index])
            var exponent = Int((bits >> 52) & UInt64(0x7FF))
            minimum_exponent = min(minimum_exponent, exponent)
            maximum_exponent = max(maximum_exponent, exponent)

    if len(signal) == 1:
        return [0.0]
    return _detrend_fitted(signal, kind, maximum_exponent - minimum_exponent > 512)
