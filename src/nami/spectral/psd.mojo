"""One-sided periodogram and Welch power spectral density estimators."""

from shuhafft import FFTNormalization, RealFFTPlan
from std.collections import List, Optional
from std.complex import ComplexSIMD
from std.io import Writable, Writer
from std.math import frexp, inf, isfinite, ldexp

from ..detrend import _scaled_mean
from ..windows.general_cosine import WindowSampling, hann


struct PowerSpectrum(Copyable, Equatable, Movable, Sized, Writable):
    """Own parallel frequency and one-sided power-density bins.

    Direct mutation of `_frequencies` or `_power` is out of contract; use
    `validate()` for an explicit checkpoint after unusual mutation.
    """

    var _frequencies: List[Float64]
    var _power: List[Float64]

    def __init__(
        out self,
        *,
        var _frequencies: List[Float64],
        var _power: List[Float64],
    ) raises:
        self._frequencies = _frequencies^
        self._power = _power^
        self.validate()

    def frequencies(self) -> Span[Float64, origin_of(self._frequencies)]:
        """Return a non-owning view of the DC-first frequency bins."""
        return Span(self._frequencies)

    def power(self) -> Span[Float64, origin_of(self._power)]:
        """Return a non-owning view of the parallel density values."""
        return Span(self._power)

    def __len__(self) -> Int:
        return len(self._frequencies)

    def validate(self) raises:
        """Raise if unusual direct mutation broke parallel storage."""
        if len(self._frequencies) != len(self._power):
            raise Error(
                String(
                    "PowerSpectrum parallel lengths must match; got frequencies=",
                    len(self._frequencies),
                    ", power=",
                    len(self._power),
                )
            )

    def __eq__(self, other: Self) -> Bool:
        if len(self) != len(other):
            return False
        for index in range(len(self)):
            if self._frequencies[index] != other._frequencies[index]:
                return False
            if self._power[index] != other._power[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("PowerSpectrum(bins=", len(self), ", one_sided_density=True)")


def _validate_sample_rate(sample_rate: Float64) raises:
    if not isfinite(sample_rate) or sample_rate <= 0.0:
        raise Error(
            String(
                "spectral sample_rate must be positive and finite; got ",
                sample_rate,
            )
        )


def _validate_fft_length(length: Int, *, operation: StringLiteral) raises:
    if length < 2:
        raise Error(
            String(
                operation,
                " length must be a power of two >= 2; got ",
                length,
                "; the smallest valid length is 2",
            )
        )
    if (length & (length - 1)) != 0:
        var lower = 1
        while lower * 2 < length:
            lower *= 2
        raise Error(
            String(
                operation,
                " length must be a power of two >= 2; got ",
                length,
                " (nearest are ",
                lower,
                " and ",
                lower * 2,
                ")",
            )
        )


def _validate_finite_signal(
    signal: Span[Float64, _], *, operation: StringLiteral
) raises:
    for index in range(len(signal)):
        if not isfinite(signal[index]):
            raise Error(
                String(
                    operation,
                    " signal must contain only finite values; got signal[",
                    index,
                    "]=",
                    signal[index],
                )
            )


def _frequencies(n_fft: Int, sample_rate: Float64) -> List[Float64]:
    var result = List[Float64](capacity=n_fft // 2 + 1)
    for index in range(n_fft // 2 + 1):
        result.append((Float64(index) / Float64(n_fft)) * sample_rate)
    return result^


def _center_frame(signal: Span[Float64, _], mut frame: List[Float64]) -> Float64:
    """Center a validated frame in normalized units without allocating."""
    var statistics = _scaled_mean(signal)
    var amplitude = statistics[0]
    var mean = statistics[1]
    for index in range(len(signal)):
        frame[index] = signal[index] / amplitude - mean
    return amplitude


def _binary_parts(value: Float64) -> Tuple[Float64, Int]:
    """Normalize subnormals before Mojo 1.0's frexp exponent-bit operation."""
    if value < 2.2250738585072014e-308:
        var parts = frexp(value * 18014398509481984.0)
        return (parts[0], Int(parts[1]) - 54)
    var parts = frexp(value)
    return (parts[0], Int(parts[1]))


def _restore_exponent(mantissa: Float64, exponent: Int) -> Float64:
    """Round once at underflow, and keep ldexp's exponent in [-1022, 1023]."""
    var parts = _binary_parts(mantissa)
    var normalized = parts[0]
    var total_exponent = exponent + parts[1]
    if total_exponent > 1024:
        return inf[DType.float64]()
    if total_exponent < -1074:
        return 0.0
    if total_exponent == 1024:
        return ldexp(normalized, Int32(1023)) * 2.0
    if total_exponent < -1022:
        return ldexp(normalized, Int32(total_exponent + 1022)) * 2.2250738585072014e-308
    return ldexp(normalized, Int32(total_exponent))


def _density(
    value: ComplexSIMD[DType.float64, 1],
    amplitude: Float64,
    sample_rate: Float64,
    energy: Float64,
    factor: Float64,
) raises -> Float64:
    """Evaluate squared amplitude / (rate * energy) using bounded mantissas."""
    var component = max(abs(value.re), abs(value.im))
    if component == 0.0:
        return 0.0
    var fft_parts = _binary_parts(component)
    var amplitude_parts = _binary_parts(amplitude)
    var rate_parts = _binary_parts(sample_rate)
    var energy_parts = _binary_parts(energy)
    var re = value.re / component
    var im = value.im / component
    var magnitude = fft_parts[0] * amplitude_parts[0]
    var mantissa = (
        magnitude
        * magnitude
        * (re * re + im * im)
        / (rate_parts[0] * energy_parts[0])
        * factor
    )
    var exponent = (
        2 * (fft_parts[1] + amplitude_parts[1]) - rate_parts[1] - energy_parts[1]
    )
    var density = _restore_exponent(mantissa, exponent)
    if not isfinite(density):
        raise Error(
            String(
                "spectral density is outside finite Float64; got ",
                density,
                "; rescale the signal or increase sample_rate=",
                sample_rate,
            )
        )
    return density


def periodogram(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
) raises -> PowerSpectrum:
    """Return a SciPy-default one-sided density periodogram.

    The complete signal is constant-detrended and transformed with a
    rectangular window. The signal length must be a power of two at least 2.
    This preserves the input and allocates a real FFT plan and tables, a
    detrended list, a compact complex FFT result, and the two result lists.
    Committed SciPy fixtures use mixed absolute/relative tolerance
    `max(1e-9, 1e-9 * abs(expected))`.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(len(signal), operation="periodogram signal")
    _validate_finite_signal(signal, operation="periodogram")

    var centered = List[Float64](length=len(signal), fill=0.0)
    var amplitude = _center_frame(signal, centered)
    var plan = RealFFTPlan[DType.float64](len(signal), FFTNormalization.BACKWARD)
    var transformed = plan.forward(centered)
    var power = List[Float64](capacity=len(transformed))
    for index in range(len(transformed)):
        var value = transformed[index]
        var factor = 1.0 if index == 0 or index == len(transformed) - 1 else 2.0
        power.append(
            _density(value, amplitude, sample_rate, Float64(len(signal)), factor)
        )

    var frequencies = _frequencies(len(signal), sample_rate)
    return PowerSpectrum(_frequencies=frequencies^, _power=power^)


def welch(
    signal: Span[Float64, _],
    sample_rate: Float64 = 1.0,
    *,
    segment_length: Int = 256,
    overlap: Optional[Int] = None,
) raises -> PowerSpectrum:
    """Return a SciPy-default one-sided Welch density estimate.

    Complete segments use a periodic Hann window, per-segment constant
    detrending, mean averaging, and half overlap by default. One real FFT plan
    and its tables are allocated once and reused. The operation preserves the
    input and allocates the window, accumulated result, real frame, and compact
    spectrum lists once. The frame and spectrum buffers are reused for every
    segment. Committed SciPy fixtures use mixed absolute/relative tolerance
    `max(1e-9, 1e-9 * abs(expected))`.
    """
    _validate_sample_rate(sample_rate)
    _validate_fft_length(segment_length, operation="welch segment")
    if len(signal) < segment_length:
        raise Error(
            String(
                "welch signal length must be >= segment_length; got ",
                "signal_length=",
                len(signal),
                ", segment_length=",
                segment_length,
            )
        )

    var actual_overlap = overlap.value() if overlap else segment_length // 2
    if actual_overlap < 0 or actual_overlap >= segment_length:
        raise Error(
            String(
                "welch overlap must satisfy 0 <= overlap < segment_length; got ",
                "overlap=",
                actual_overlap,
                ", segment_length=",
                segment_length,
            )
        )
    _validate_finite_signal(signal, operation="welch")

    var window = hann(segment_length, WindowSampling.PERIODIC)
    var window_energy = 0.0
    for index in range(len(window)):
        window_energy += window[index] * window[index]
    var step = segment_length - actual_overlap
    var segment_count = (len(signal) - segment_length) // step + 1
    var bin_count = segment_length // 2 + 1
    var accumulated = List[Float64](length=bin_count, fill=0.0)
    var plan = RealFFTPlan[DType.float64](segment_length, FFTNormalization.BACKWARD)
    var frame = List[Float64](length=segment_length, fill=0.0)
    var spectrum = List[ComplexSIMD[DType.float64, 1]](
        length=bin_count, fill=ComplexSIMD[DType.float64, 1](0.0)
    )

    for segment_index in range(segment_count):
        var start = segment_index * step
        var amplitude = _center_frame(signal[start : start + segment_length], frame)
        for index in range(segment_length):
            frame[index] *= window[index]
        plan.forward_into(frame, spectrum)
        for index in range(bin_count):
            var value = spectrum[index]
            var factor = 1.0 if index == 0 or index == bin_count - 1 else 2.0
            accumulated[index] += _density(
                value,
                amplitude,
                sample_rate,
                window_energy,
                factor / Float64(segment_count),
            )
            if not isfinite(accumulated[index]):
                raise Error(
                    "spectral density is outside finite Float64; rescale the signal"
                )

    var frequencies = _frequencies(segment_length, sample_rate)
    return PowerSpectrum(_frequencies=frequencies^, _power=accumulated^)
